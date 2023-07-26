(* initool -- manipulate the contents of INI files from the command line
 * Copyright (c) 2015-2018 D. Bohdan
 * License: MIT
 *)

fun readLines (filename : string) : string list =
  let
    val file = case filename of
        "-" => TextIO.stdIn
      | _ => TextIO.openIn filename
    val contents = TextIO.inputAll file
    val _ = TextIO.closeIn file
    val contentsNoTrailingNewline =
      if String.isSuffix "\n" contents then
        String.extract (contents, 0, SOME((String.size contents) - 1))
      else contents
  in
    String.fields (fn c => c = #"\n") contentsNoTrailingNewline
  end

fun withNewline (s : string) =
  if s = "" orelse String.isSuffix "\n" s then
    s
  else
    s ^ "\n"

fun printFlush (stream : TextIO.outstream) (s : string) =
  let
    val _ = TextIO.output (stream, withNewline s)
  in
    TextIO.flushOut stream
  end

fun exitWithError (message : string) =
  let
    val _ = printFlush TextIO.stdErr message
  in
    OS.Process.exit(OS.Process.failure)
  end

datatype result = Output of string | Notification of string | Error of string

fun processFile filterFn filename =
  Output ((Ini.stringify o filterFn o Ini.parse o readLines) filename)

val usage =
    ("usage: initool g filename [section [key [--value-only]]]\n" ^
     "       initool e filename section [key]\n" ^
     "       initool d filename section [key]\n" ^
     "       initool s filename section key value\n" ^
     "       initool v\n")


fun processArgs [] =
    Notification usage
  | processArgs ["h"] =
    processArgs []
  | processArgs ["help"] =
    processArgs []
  | processArgs ["-h"] =
    processArgs []
  | processArgs ["-help"] =
    processArgs []
  | processArgs ["--help"] =
    processArgs []
  | processArgs ["-?"] =
    processArgs []
  | processArgs ["/?"] =
    processArgs []
  | processArgs ["v"] =
    let
      val version = "0.10.1"
    in
      Output (version ^ "\n")
    end
  | processArgs ["g", filename] =
    processFile (fn x => x) filename
  | processArgs ["g", filename, section] =
    (* Get section *)
    processFile (Ini.select (Ini.SelectSection section)) filename
  | processArgs ["g", filename, section, key] =
    (* Get property *)
    let
      val q = Ini.SelectProperty { section = section, key = key }
    in
      processFile (Ini.select q) filename
    end
  | processArgs ["g", filename, section, key, "--value-only"] =
    (* Get only the value *)
    let
      val q = Ini.SelectProperty { section = section, key = key }
      val selection = ((Ini.select q) o Ini.parse o readLines) filename
    in
      case selection of
          [{ name = _,
              contents = [Ini.Property { key = _, value }] }] =>
          Output (value ^ "\n")
        (* Treat unset properties as blank. *)
        | _ => Output ""
    end
  | processArgs ["e", filename, section] =
    (* Section exists *)
    let
      val q = Ini.SelectSection section
    in
      case (Ini.select q o Ini.parse o readLines) filename of
          [] => Error ""
        | _ => Output ""
    end
  | processArgs ["e", filename, section, key] =
    (* Property exists *)
    let
      val q = Ini.SelectProperty { section = section, key = key }
    in
      case (Ini.select q o Ini.parse o readLines) filename of
          [{contents = [Ini.Property { key = key, value = _ }], name = _ }] =>
            Output ""
        | _ => Error ""
    end
  | processArgs ["d", filename, section] =
    (* Delete section *)
    processFile (Ini.select (Ini.RemoveSection section)) filename
  | processArgs ["d", filename, section, key] =
    (* Delete property *)
    let
      val q = Ini.RemoveProperty { section = section, key = key }
    in
      processFile (Ini.select q) filename
    end
  | processArgs ["s", filename, section, key, value] =
    (* Set value *)
    let
      val update = [{
        name = section,
        contents = [Ini.Property { key = key, value = value }]
      }]
    in
      processFile (Ini.merge update) filename
    end
  | processArgs _ =
    Error usage

val args = CommandLine.arguments ()

val result = processArgs args
  handle Ini.Tokenization(message) => exitWithError ("Error: " ^ message)
val _ = case result of
    Output s => printFlush TextIO.stdOut s
  | Notification s => printFlush TextIO.stdErr s
  | Error s => exitWithError s

val _ = OS.Process.exit (OS.Process.success)
