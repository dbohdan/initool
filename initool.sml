(* initool -- manipulate the contents of INI files from the command line
 * Copyright (c) 2015-2018, 2023 D. Bohdan
 * License: MIT
 *)

fun readLines (filename: string) : string list =
  let
    val file =
      case filename of
        "-" => TextIO.stdIn
      | _ => TextIO.openIn filename
    val contents = TextIO.inputAll file
    val _ = TextIO.closeIn file
    val contentsNoTrailingNewline =
      if String.isSuffix "\n" contents then
        String.extract (contents, 0, SOME ((String.size contents) - 1))
      else
        contents
  in
    String.fields (fn c => c = #"\n") contentsNoTrailingNewline
  end

fun withNewlineIfNotEmpty (s: string) =
  if s = "" orelse String.isSuffix "\n" s then s else s ^ "\n"

fun printFlush (stream: TextIO.outstream) (s: string) =
  let val _ = TextIO.output (stream, withNewlineIfNotEmpty s)
  in TextIO.flushOut stream
  end

fun exitWithError (output: string) (err: string) =
  let
    val _ = printFlush TextIO.stdOut output
    val _ = printFlush TextIO.stdErr err
  in
    OS.Process.exit (OS.Process.failure)
  end

datatype result =
  Output of string
| FailureOutput of string
| Error of string

fun processFileCustom quiet successFn filterFn filename =
  let
    val parsed = (Ini.parse o readLines) filename
    val filtered = filterFn parsed
    val success = successFn (parsed, filtered)
    val output = if quiet then "" else Ini.stringify filtered
  in
    if success then Output output else FailureOutput output
  end

val processFile = processFileCustom false
val processFileQuiet = processFileCustom true

val getUsage = " <filename> [<section> [<key> [-v|--value-only]]]"
val existsUsage = " <filename> <section> [<key>]"
val setUsage = " <filename> <section> <key> <value>"
val deleteUsage = " <filename> <section> [<key>]"

val availableCommands =
  "available commands: get, exists, set, delete, help, version"
val invalidUsage = "invalid usage: "
val unknownCommand = "unknown command: "
val usage = "usage: "

val allUsage =
  (usage ^ "initool [-i|--ignore-case] <command> [<arg> ...]\n\n" ^ "commands:"
   ^
   (String.concatWith "\n    "
      [ ""
      , "get" ^ getUsage
      , "exists" ^ existsUsage
      , "set" ^ setUsage
      , "delete" ^ deleteUsage
      ]) ^ "\n\n    help\n    version\n\n"
   ^ "Each command can be abbreviated to its first letter. "
   ^ "<section> and <key> can be '*' to match anything.")

fun formatArgs (args: string list) =
  let
    val escapeSpecial = fn s =>
      String.translate
        (fn #"\"" => "\\\"" | #"\\" => "\\\\" | c => String.str c) s
    val shouldQuote = fn s =>
      List.exists (fn c => Char.isSpace c orelse c = #"\"" orelse c = #"\\")
        (String.explode s)
    val quoteArg = fn arg =>
      if shouldQuote arg then "\"" ^ (escapeSpecial arg) ^ "\"" else arg
  in
    String.concatWith " " (List.map quoteArg args)
  end

fun helpCommand [] = Output allUsage
  | helpCommand [_] = helpCommand []
  | helpCommand (cmd :: rest) =
      Error (invalidUsage ^ (formatArgs (cmd :: rest)) ^ "\n" ^ usage ^ cmd)

fun versionCommand [] =
      let val version = "0.13.0"
      in Output (version ^ "\n")
      end
  | versionCommand [_] = versionCommand []
  | versionCommand (cmd :: rest) =
      Error (invalidUsage ^ (formatArgs (cmd :: rest)) ^ "\n" ^ usage ^ cmd)

fun getCommand (opts: Id.options) [_, filename] =
      processFile (fn _ => true) (fn x => x) filename
  | getCommand opts [_, filename, section] =
      (* Get section *)
      processFile (fn (_, filtered) => filtered <> [])
        (Ini.select opts ((Ini.SelectSection o Id.fromStringWildcard) section))
        filename
  | getCommand opts [_, filename, section, key] =
      (* Get property *)
      let
        val section = Id.fromStringWildcard section
        val key = Id.fromStringWildcard key
        val successFn = fn (_, filtered) =>
          Ini.propertyExists opts section key filtered
        val q = Ini.SelectProperty {section = section, key = key}
        val filterFn = fn sections =>
          (Ini.removeEmptySections o (Ini.select opts q)) sections
      in
        processFile successFn filterFn filename
      end
  | getCommand opts [cmd, filename, section, key, "-v"] =
      getCommand opts [cmd, filename, section, key, "--value-only"]
  | getCommand opts [_, filename, section, key, "--value-only"] =
      (* Get only the value *)
      let
        val section = Id.fromStringWildcard section
        val key = Id.fromStringWildcard key
        val successFn = fn (_, filtered) =>
          Ini.propertyExists opts section key filtered
        val q = Ini.SelectProperty {section = section, key = key}
        val parsed = ((Ini.select opts q) o Ini.parse o readLines) filename
        val allItems = List.concat
          (List.map (fn {name = _, contents = xs} => xs) parsed)
        val values =
          List.mapPartial
            (fn Ini.Property {key = _, value = value} => SOME value | _ => NONE)
            allItems
        val output = String.concatWith "\n" values
      in
        if values = [] then Error output else Output output
      end
  | getCommand opts (cmd :: rest) =
      Error
        (invalidUsage ^ (formatArgs (cmd :: rest)) ^ "\n" ^ usage ^ cmd
         ^ getUsage)
  | getCommand opts [] = getCommand opts ["get"]


fun existsCommand (opts: Id.options) [_, filename, section] =
      (* Section exists *)
      let
        val successFn = fn (parsed, _) =>
          Ini.sectionExists opts (Id.fromStringWildcard section) parsed
      in
        processFileQuiet successFn (fn x => x) filename
      end
  | existsCommand opts [_, filename, section, key] =
      (* Property exists *)
      let
        val section = Id.fromStringWildcard section
        val key = Id.fromStringWildcard key
        val successFn = fn (parsed, _) =>
          Ini.propertyExists opts section key parsed
      in
        processFileQuiet successFn (fn x => x) filename
      end
  | existsCommand opts (cmd :: rest) =
      Error
        (invalidUsage ^ (formatArgs (cmd :: rest)) ^ "\n" ^ usage ^ cmd
         ^ existsUsage)
  | existsCommand opts [] = existsCommand opts ["exists"]

fun setCommand (opts: Id.options) [_, filename, section, key, value] =
      (* Set value *)
      let
        val update =
          [{ name = Id.fromStringWildcard section
           , contents =
               [Ini.Property {key = Id.fromStringWildcard key, value = value}]
           }]
      in
        processFile (fn _ => true) (Ini.merge opts update) filename
      end
  | setCommand opts (cmd :: rest) =
      Error
        (invalidUsage ^ (formatArgs (cmd :: rest)) ^ "\n" ^ usage ^ cmd
         ^ setUsage)
  | setCommand opts [] = setCommand opts ["set"]

fun deleteCommand (opts: Id.options) [_, filename, section] =
      (* Delete section *)
      let
        val successFn = fn (parsed, _) =>
          Ini.sectionExists opts (Id.fromStringWildcard section) parsed
      in
        processFile successFn
          (Ini.select opts (Ini.RemoveSection (Id.fromStringWildcard section)))
          filename
      end
  | deleteCommand opts [_, filename, section, key] =
      (* Delete property *)
      let
        val q =
          Ini.RemoveProperty
            { section = Id.fromStringWildcard section
            , key = Id.fromStringWildcard key
            }
        val successFn = fn (parsed, _) =>
          Ini.sectionExists opts (Id.fromStringWildcard section) parsed
      in
        processFile successFn (Ini.select opts q) filename
      end
  | deleteCommand opts (cmd :: rest) =
      Error
        (invalidUsage ^ (formatArgs (cmd :: rest)) ^ "\n" ^ usage ^ cmd
         ^ deleteUsage)
  | deleteCommand opts [] = deleteCommand opts ["delete"]

fun processArgs (opts: Id.options) [] = helpCommand []
  | processArgs opts ("h" :: args) =
      helpCommand ("h" :: args)
  | processArgs opts ("-h" :: args) =
      helpCommand ("-h" :: args)
  | processArgs opts ("-help" :: args) =
      helpCommand ("-help" :: args)
  | processArgs opts ("--help" :: args) =
      helpCommand ("--help" :: args)
  | processArgs opts ("-?" :: args) =
      helpCommand ("-?" :: args)
  | processArgs opts ("/?" :: args) =
      helpCommand ("/?" :: args)
  | processArgs opts ("help" :: args) =
      helpCommand ("help" :: args)
  | processArgs opts ("v" :: args) =
      versionCommand ("v" :: args)
  | processArgs opts ("version" :: args) =
      versionCommand ("version" :: args)
  | processArgs opts ("-i" :: args) =
      processArgs {ignoreCase = true} args
  | processArgs opts ("--ignore-case" :: args) =
      processArgs {ignoreCase = true} args
  | processArgs opts ("g" :: args) =
      getCommand opts ("g" :: args)
  | processArgs opts ("get" :: args) =
      getCommand opts ("get" :: args)
  | processArgs opts ("e" :: args) =
      existsCommand opts ("e" :: args)
  | processArgs opts ("exists" :: args) =
      existsCommand opts ("exists" :: args)
  | processArgs opts ("s" :: args) =
      setCommand opts ("s" :: args)
  | processArgs opts ("set" :: args) =
      setCommand opts ("set" :: args)
  | processArgs opts ("d" :: args) =
      deleteCommand opts ("d" :: args)
  | processArgs opts ("delete" :: args) =
      deleteCommand opts ("delete" :: args)
  | processArgs opts (cmd :: _) =
      Error (unknownCommand ^ (formatArgs [cmd]) ^ "\n" ^ availableCommands)

val args = CommandLine.arguments ()

val result =
  processArgs {ignoreCase = false} args
  handle Ini.Tokenization (message) => exitWithError "" ("Error: " ^ message)
val _ =
  case result of
    Output s => printFlush TextIO.stdOut s
  | FailureOutput s => exitWithError s ""
  | Error s => exitWithError "" s

val _ = OS.Process.exit (OS.Process.success)
