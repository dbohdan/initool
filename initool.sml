(* initool -- manipulate the contents of INI files from the command line
 * Copyright (c) 2015, 2016, 2017, 2018 dbohdan
 * License: MIT
 *)

fun readLines (filename : string) : string list =
  let
    val file = TextIO.openIn filename
    val contents = TextIO.inputAll file
    val _ = TextIO.closeIn file
    val contentsNoTrailingNewline =
      if String.isSuffix "\n" contents then
        String.extract (contents, 0, SOME((String.size contents) - 1))
      else contents
  in
    String.fields (fn c => c = #"\n") contentsNoTrailingNewline
  end

fun exitWithError (message : string) =
  let
    val fullMessage = "Error: " ^ message ^ "\n"
    val _ = TextIO.output (TextIO.stdErr, fullMessage)
    val _ = TextIO.flushOut TextIO.stdErr
  in
    OS.Process.exit(OS.Process.failure)
  end

fun processFile filterFn filename =
  SOME ((Ini.stringify o filterFn o Ini.parse o readLines) filename)

fun processArgs [] =
    SOME
      ("Usage: initool g filename [section [key [--value-only]]]\n" ^
       "       initool e filename [section [key]]\n" ^
       "       initool d filename section [key]\n" ^
       "       initool s filename section key value\n" ^
       "       initool v\n")
  | processArgs ["v"] =
    let
      val version = "0.9.0"
    in
      SOME (version ^ "\n")
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
          SOME (value ^ "\n")
        (* Treat unset properties as blank. *)
        | _ => SOME ""
    end
  | processArgs ["e", filename, section] =
    (* Section exists *)
    let
      val q = Ini.SelectSection section
    in
      case (Ini.select q o Ini.parse o readLines) filename of
          [] => NONE
        | _ => SOME ""
    end
  | processArgs ["e", filename, section, key] =
    (* Property exists *)
    let
      val q = Ini.SelectProperty { section = section, key = key }
    in
      case (Ini.select q o Ini.parse o readLines) filename of
          [{contents = [Ini.Property { key = key, value = _ }], name = _ }] =>
            SOME ""
        | _ => NONE
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
    processArgs []

val args = CommandLine.arguments ()
val result = processArgs args
  handle Ini.Tokenization(message) => exitWithError message
val _ = case result of
    SOME(s) => print s
  | NONE => OS.Process.exit (OS.Process.failure)
val _ = OS.Process.exit (OS.Process.success)
