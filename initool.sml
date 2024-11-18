(* initool -- manipulate the contents of INI files from the command line
 * Copyright (c) 2015-2018, 2023-2024 D. Bohdan
 * License: MIT
 *)

exception Encoding of string

val unsupportedEncoding = "unsupported encoding: "

fun checkWrongEncoding (lines: string list) =
  let
    val _ =
      case lines of
        first :: _ =>
          (case map Char.ord (String.explode first) of
             0x00 :: 0x00 :: 0xFE :: 0xFF :: _ =>
               raise Encoding (unsupportedEncoding ^ "UTF-32 BE")
           | 0xFF :: 0xFE :: 0x00 :: 0x00 :: _ =>
               raise Encoding (unsupportedEncoding ^ "UTF-32 LE")
           | 0xFE :: 0xFF :: _ =>
               raise Encoding (unsupportedEncoding ^ "UTF-16 BE")
           | 0xFF :: 0xFE :: _ =>
               raise Encoding (unsupportedEncoding ^ "UTF-16 LE")
           | _ => ())
      | _ => ()
  in
    lines
  end

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

datatype result = Output of string | FailureOutput of string | Error of string

fun processFileCustom quiet passThrough successFn filterFn filename =
  let
    val parsed =
      ((Ini.parse passThrough) o checkWrongEncoding o readLines) filename
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
val replaceUsage = " <filename> <section> <key> <text> <replacement>"
val deleteUsage = " <filename> <section> [<key>]"

val availableCommands =
  "available commands: get, exists, set, replace, delete, help, version"
val invalidUsage = "invalid usage: "
val unknownCommand = "unknown command: "
val usage = "usage: "

val allUsage =
  (usage ^ "initool [-i|--ignore-case] [-p|--pass-through] "
   ^ "<command> [<arg> ...]\n\n" ^ "commands:"
   ^
   (String.concatWith "\n    "
      [ ""
      , "get" ^ getUsage
      , "exists" ^ existsUsage
      , "set" ^ setUsage
      , "replace" ^ replaceUsage
      , "delete" ^ deleteUsage
      ]) ^ "\n\n    help\n    version\n\n"
   ^ "Each command can be abbreviated to its first letter. "
   ^ "<section>, <key>, and <text> can be '*' or '_' to match anything. "
   ^ "Empty <text> matches empty values.")

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
      let val version = "1.0.0"
      in Output (version ^ "\n")
      end
  | versionCommand [_] = versionCommand []
  | versionCommand (cmd :: rest) =
      Error (invalidUsage ^ (formatArgs (cmd :: rest)) ^ "\n" ^ usage ^ cmd)

type options = {ignoreCase: bool, passThrough: bool}

fun idOptions (opts: options) : Id.options = {ignoreCase = #ignoreCase opts}

fun getCommand (opts: options) [_, filename] =
      processFile (#passThrough opts) (fn _ => true) (fn x => x) filename
  | getCommand opts [_, filename, section] =
      (* Get section *)
      processFile (#passThrough opts) (fn (_, filtered) => filtered <> [])
        (Ini.select (idOptions opts)
           ((Ini.SelectSection o Id.fromStringWildcard) section)) filename
  | getCommand opts [_, filename, section, key] =
      (* Get property *)
      let
        val section = Id.fromStringWildcard section
        val key = Id.fromStringWildcard key
        val successFn = fn (_, filtered) =>
          Ini.propertyExists (idOptions opts) section key Id.Wildcard filtered
        val q =
          Ini.SelectProperty
            {section = section, key = key, pattern = Id.Wildcard}
        val filterFn = fn sections =>
          (Ini.removeEmptySections o (Ini.select (idOptions opts) q)) sections
      in
        processFile (#passThrough opts) successFn filterFn filename
      end
  | getCommand opts [cmd, filename, section, key, "-v"] =
      getCommand opts [cmd, filename, section, key, "--value-only"]
  | getCommand opts [_, filename, section, key, "--value-only"] =
      (* Get only the value *)
      let
        val section = Id.fromStringWildcard section
        val key = Id.fromStringWildcard key
        val successFn = fn (_, filtered) =>
          Ini.propertyExists (idOptions opts) section key Id.Wildcard filtered
        val q =
          Ini.SelectProperty
            {section = section, key = key, pattern = Id.Wildcard}
        val parsed =
          ((Ini.select (idOptions opts) q) o (Ini.parse (#passThrough opts))
           o checkWrongEncoding o readLines) filename
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

fun existsCommand (opts: options) [_, filename, section] =
      (* Section exists *)
      let
        val successFn = fn (parsed, _) =>
          Ini.sectionExists (idOptions opts) (Id.fromStringWildcard section)
            parsed
      in
        processFileQuiet (#passThrough opts) successFn (fn x => x) filename
      end
  | existsCommand opts [_, filename, section, key] =
      (* Property exists *)
      let
        val section = Id.fromStringWildcard section
        val key = Id.fromStringWildcard key
        val successFn = fn (parsed, _) =>
          Ini.propertyExists (idOptions opts) section key Id.Wildcard parsed
      in
        processFileQuiet (#passThrough opts) successFn (fn x => x) filename
      end
  | existsCommand opts (cmd :: rest) =
      Error
        (invalidUsage ^ (formatArgs (cmd :: rest)) ^ "\n" ^ usage ^ cmd
         ^ existsUsage)
  | existsCommand opts [] = existsCommand opts ["exists"]

fun setCommand (opts: options) [_, filename, section, key, value] =
      (* Set value *)
      let
        val update =
          [{ name = Id.fromStringWildcard section
           , contents =
               [Ini.Property {key = Id.fromStringWildcard key, value = value}]
           }]
      in
        processFile (#passThrough opts) (fn _ => true)
          (Ini.merge (idOptions opts) update) filename
      end
  | setCommand opts (cmd :: rest) =
      Error
        (invalidUsage ^ (formatArgs (cmd :: rest)) ^ "\n" ^ usage ^ cmd
         ^ setUsage)
  | setCommand opts [] = setCommand opts ["set"]

fun replaceCommand (opts: options)
      [_, filename, section, key, pattern, replacement] =
      (* Replace pattern in value *)
      let
        val section = Id.fromStringWildcard section
        val key = Id.fromStringWildcard key
        val pattern = Id.fromStringWildcard pattern
        val q = Ini.ReplaceInValue
          { section = section
          , key = key
          , pattern = pattern
          , replacement = replacement
          }
        val successFn = fn (parsed, _) =>
          Ini.propertyExists (idOptions opts) section key pattern parsed
      in
        processFile (#passThrough opts) successFn
          (Ini.select (idOptions opts) q) filename
      end
  | replaceCommand opts (cmd :: rest) =
      Error
        (invalidUsage ^ (formatArgs (cmd :: rest)) ^ "\n" ^ usage ^ cmd
         ^ replaceUsage)
  | replaceCommand opts [] = replaceCommand opts ["replace"]

fun deleteCommand (opts: options) [_, filename, section] =
      (* Delete section *)
      let
        val successFn = fn (parsed, _) =>
          Ini.sectionExists (idOptions opts) (Id.fromStringWildcard section)
            parsed
      in
        processFile (#passThrough opts) successFn
          (Ini.select (idOptions opts)
             (Ini.RemoveSection (Id.fromStringWildcard section))) filename
      end
  | deleteCommand opts [_, filename, section, key] =
      (* Delete property *)
      let
        val section = Id.fromStringWildcard section
        val key = Id.fromStringWildcard key
        val q = Ini.RemoveProperty {section = section, key = key}
        val successFn = fn (parsed, _) =>
          Ini.propertyExists (idOptions opts) section key Id.Wildcard parsed
      in
        processFile (#passThrough opts) successFn
          (Ini.select (idOptions opts) q) filename
      end
  | deleteCommand opts (cmd :: rest) =
      Error
        (invalidUsage ^ (formatArgs (cmd :: rest)) ^ "\n" ^ usage ^ cmd
         ^ deleteUsage)
  | deleteCommand opts [] = deleteCommand opts ["delete"]

fun processArgs (opts: options) [] = helpCommand []
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
      processArgs {ignoreCase = true, passThrough = #passThrough opts} args
  | processArgs opts ("--ignore-case" :: args) =
      processArgs {ignoreCase = true, passThrough = #passThrough opts} args
  | processArgs opts ("-p" :: args) =
      processArgs {ignoreCase = #ignoreCase opts, passThrough = true} args
  | processArgs opts ("--pass-through" :: args) =
      processArgs {ignoreCase = #ignoreCase opts, passThrough = true} args
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
  | processArgs opts ("r" :: args) =
      replaceCommand opts ("r" :: args)
  | processArgs opts ("replace" :: args) =
      replaceCommand opts ("replace" :: args)
  | processArgs opts ("d" :: args) =
      deleteCommand opts ("d" :: args)
  | processArgs opts ("delete" :: args) =
      deleteCommand opts ("delete" :: args)
  | processArgs opts (cmd :: _) =
      Error (unknownCommand ^ (formatArgs [cmd]) ^ "\n" ^ availableCommands)

fun handleException (message: string) =
  exitWithError "" ("Error: " ^ message)

val args = CommandLine.arguments ()

val result =
  processArgs {ignoreCase = false, passThrough = false} args
  handle
    Encoding message => handleException message
  | Ini.Tokenization message => handleException message
val _ =
  case result of
    Output s => printFlush TextIO.stdOut s
  | FailureOutput s => exitWithError s ""
  | Error s => exitWithError "" s

val _ = OS.Process.exit (OS.Process.success)
