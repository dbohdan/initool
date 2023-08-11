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

fun exitWithError (message: string) =
  let val _ = printFlush TextIO.stdErr message
  in OS.Process.exit (OS.Process.failure)
  end

datatype result = Output of string | Notification of string | Error of string

fun processFile filterFn filename =
  Output ((Ini.stringify o filterFn o Ini.parse o readLines) filename)

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
  (usage ^ "initool <command> [<arg> ...]\n\n" ^ "commands:"
   ^
   (String.concatWith "\n    "
      [ ""
      , "get" ^ getUsage
      , "exists" ^ existsUsage
      , "set" ^ setUsage
      , "delete" ^ deleteUsage
      ]) ^ "\n\n    help\n    version\n\n"
   ^ "Each command can be abbreviated to its first letter.")

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

fun helpCommand [] = Notification allUsage
  | helpCommand [_] = helpCommand []
  | helpCommand (cmd :: rest) =
      Error (invalidUsage ^ (formatArgs (cmd :: rest)) ^ "\n" ^ usage ^ cmd)

fun versionCommand [] =
      let val version = "0.12.0"
      in Output (version ^ "\n")
      end
  | versionCommand [_] = versionCommand []
  | versionCommand (cmd :: rest) =
      Error (invalidUsage ^ (formatArgs (cmd :: rest)) ^ "\n" ^ usage ^ cmd)

fun getCommand [_, filename] =
      processFile (fn x => x) filename
  | getCommand [_, filename, section] =
      (* Get section *)
      processFile (Ini.select (Ini.SelectSection section)) filename
  | getCommand [_, filename, section, key] =
      (* Get property *)
      let val q = Ini.SelectProperty {section = section, key = key}
      in processFile (Ini.select q) filename
      end
  | getCommand [cmd, filename, section, key, "-v"] =
      getCommand [cmd, filename, section, key, "--value-only"]
  | getCommand [_, filename, section, key, "--value-only"] =
      (* Get only the value *)
      let
        val q = Ini.SelectProperty {section = section, key = key}
        val selection = ((Ini.select q) o Ini.parse o readLines) filename
      in
        case selection of
          [{name = _, contents = [Ini.Property {key = _, value}]}] =>
            Output (value ^ "\n")
        (* Treat unset properties as blank. *)
        | _ => Output ""
      end
  | getCommand (cmd :: rest) =
      Error
        (invalidUsage ^ (formatArgs (cmd :: rest)) ^ "\n" ^ usage ^ cmd
         ^ getUsage)
  | getCommand [] = getCommand ["get"]

fun existsCommand [_, filename, section] =
      (* Section exists *)
      let
        val q = Ini.SelectSection section
      in
        case (Ini.select q o Ini.parse o readLines) filename of
          [] => Error ""
        | _ => Output ""
      end
  | existsCommand [_, filename, section, key] =
      (* Property exists *)
      let
        val q = Ini.SelectProperty {section = section, key = key}
      in
        case (Ini.select q o Ini.parse o readLines) filename of
          [{contents = [Ini.Property {key = key, value = _}], name = _}] =>
            Output ""
        | _ => Error ""
      end
  | existsCommand (cmd :: rest) =
      Error
        (invalidUsage ^ (formatArgs (cmd :: rest)) ^ "\n" ^ usage ^ cmd
         ^ existsUsage)
  | existsCommand [] = existsCommand ["exists"]

fun setCommand [_, filename, section, key, value] =
      (* Set value *)
      let
        val update =
          [{ name = section
           , contents = [Ini.Property {key = key, value = value}]
           }]
      in
        processFile (Ini.merge update) filename
      end
  | setCommand (cmd :: rest) =
      Error
        (invalidUsage ^ (formatArgs (cmd :: rest)) ^ "\n" ^ usage ^ cmd
         ^ setUsage)
  | setCommand [] = setCommand ["set"]

fun deleteCommand [_, filename, section] =
      (* Delete section *)
      processFile (Ini.select (Ini.RemoveSection section)) filename
  | deleteCommand [_, filename, section, key] =
      (* Delete property *)
      let val q = Ini.RemoveProperty {section = section, key = key}
      in processFile (Ini.select q) filename
      end
  | deleteCommand (cmd :: rest) =
      Error
        (invalidUsage ^ (formatArgs (cmd :: rest)) ^ "\n" ^ usage ^ cmd
         ^ deleteUsage)
  | deleteCommand [] = deleteCommand ["delete"]

fun processArgs [] = helpCommand []
  | processArgs ("h" :: args) =
      helpCommand ("h" :: args)
  | processArgs ("-h" :: args) =
      helpCommand ("-h" :: args)
  | processArgs ("-help" :: args) =
      helpCommand ("-help" :: args)
  | processArgs ("--help" :: args) =
      helpCommand ("--help" :: args)
  | processArgs ("-?" :: args) =
      helpCommand ("-?" :: args)
  | processArgs ("/?" :: args) =
      helpCommand ("/?" :: args)
  | processArgs ("help" :: args) =
      helpCommand ("help" :: args)
  | processArgs ("v" :: args) =
      versionCommand ("v" :: args)
  | processArgs ("version" :: args) =
      versionCommand ("version" :: args)
  | processArgs ("g" :: args) =
      getCommand ("g" :: args)
  | processArgs ("get" :: args) =
      getCommand ("get" :: args)
  | processArgs ("e" :: args) =
      existsCommand ("e" :: args)
  | processArgs ("exists" :: args) =
      existsCommand ("exists" :: args)
  | processArgs ("s" :: args) =
      setCommand ("s" :: args)
  | processArgs ("set" :: args) =
      setCommand ("set" :: args)
  | processArgs ("d" :: args) =
      deleteCommand ("d" :: args)
  | processArgs ("delete" :: args) =
      deleteCommand ("delete" :: args)
  | processArgs (cmd :: _) =
      Error (unknownCommand ^ (formatArgs [cmd]) ^ "\n" ^ availableCommands)

val args = CommandLine.arguments ()

val result =
  processArgs args
  handle Ini.Tokenization (message) => exitWithError ("Error: " ^ message)
val _ =
  case result of
    Output s => printFlush TextIO.stdOut s
  | Notification s => printFlush TextIO.stdErr s
  | Error s => exitWithError s

val _ = OS.Process.exit (OS.Process.success)
