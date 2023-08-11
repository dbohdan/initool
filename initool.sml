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

val usage =
  ("usage: initool <command> [<arg> ...]\n\n" ^ "commands:\n"
   ^ "    get <filename> [<section> [<key> [-v|--value-only]]]\n"
   ^ "    exists <filename> <section> [<key>]\n"
   ^ "    set <filename> <section> <key> <value>\n"
   ^ "    delete <filename> <section> [<key>]\n" ^ "    version\n\n"
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

fun processArgs [] = Notification usage
  | processArgs ["h"] = processArgs []
  | processArgs ["help"] = processArgs []
  | processArgs ["-h"] = processArgs []
  | processArgs ["-help"] = processArgs []
  | processArgs ["--help"] = processArgs []
  | processArgs ["-?"] = processArgs []
  | processArgs ["/?"] = processArgs []
  | processArgs ["v"] = processArgs ["version"]
  | processArgs ["version"] =
      let val version = "0.12.0"
      in Output (version ^ "\n")
      end
  | processArgs ("g" :: rest) =
      processArgs ("get" :: rest)
  | processArgs ["get", filename] =
      processFile (fn x => x) filename
  | processArgs ["get", filename, section] =
      (* Get section *)
      processFile (Ini.select (Ini.SelectSection section)) filename
  | processArgs ["get", filename, section, key] =
      (* Get property *)
      let val q = Ini.SelectProperty {section = section, key = key}
      in processFile (Ini.select q) filename
      end
  | processArgs ["get", filename, section, key, "-v"] =
      processArgs ["get", filename, section, key, "--value-only"]
  | processArgs ["get", filename, section, key, "--value-only"] =
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
  | processArgs ("e" :: rest) =
      processArgs ("exists" :: rest)
  | processArgs ["exists", filename, section] =
      (* Section exists *)
      let
        val q = Ini.SelectSection section
      in
        case (Ini.select q o Ini.parse o readLines) filename of
          [] => Error ""
        | _ => Output ""
      end
  | processArgs ["exists", filename, section, key] =
      (* Property exists *)
      let
        val q = Ini.SelectProperty {section = section, key = key}
      in
        case (Ini.select q o Ini.parse o readLines) filename of
          [{contents = [Ini.Property {key = key, value = _}], name = _}] =>
            Output ""
        | _ => Error ""
      end
  | processArgs ["delete", filename, section] =
      (* Delete section *)
      processFile (Ini.select (Ini.RemoveSection section)) filename
  | processArgs ("d" :: rest) =
      processArgs ("delete" :: rest)
  | processArgs ["delete", filename, section, key] =
      (* Delete property *)
      let val q = Ini.RemoveProperty {section = section, key = key}
      in processFile (Ini.select q) filename
      end
  | processArgs ("s" :: rest) =
      processArgs ("set" :: rest)
  | processArgs ["set", filename, section, key, value] =
      (* Set value *)
      let
        val update =
          [{ name = section
           , contents = [Ini.Property {key = key, value = value}]
           }]
      in
        processFile (Ini.merge update) filename
      end
  | processArgs args =
      Error ("invalid command: " ^ (formatArgs args))

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
