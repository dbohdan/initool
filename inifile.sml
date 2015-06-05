(* IniFile *)

(* key=value in an ini file *)
type assignment = { key : string, value : string }
type sectionContents = assignment list option
type section = { name : string, contents : sectionContents }
type inifile = section list option

datatype linetype = AssignmentLine of assignment | SectionLine of section
datatype query =  AnythingQuery | StringQuery of string

fun readFile (filename : string) : string list =
    let
        val file = TextIO.openIn filename
        val contents = TextIO.inputAll file
        val _ = TextIO.closeIn file
    in
        String.tokens (fn c => c = #"\n") contents
    end

fun exitWithError (message: string) =
    let
        val fullMessage = "Error: " ^ message ^ "\n"
        val _ = TextIO.output (TextIO.stdErr, fullMessage)
        val _ = TextIO.flushOut TextIO.stdErr
    in
        OS.Process.exit(OS.Process.failure)
    end

(* A very rough tokenizer for INI lines. *)
fun parseLine (line : string) : linetype =
    let
        val isSection =
            (String.isPrefix "[" line) andalso (String.isSuffix "]" line)
        val assignFields = (String.fields (fn c => c = #"=") line)
        val isAssignment = (List.length assignFields) = 2
    in
        case (isSection, isAssignment) of
            (true, false) =>
                SectionLine ({
                    name = line,
                    contents = NONE
                })
            | (false, true) =>
                let
                    val [key, value] = assignFields
                in
                    AssignmentLine({ key = key, value = value })
                end
            | (_, _) =>
                raise Fail("invalid line: " ^ line)
    end

fun parseIni (lines : string list) : inifile =
    let
        val tokenizedLines = map parseLine lines
    in
        NONE
    end

fun processArgs [] =
        let
            val _ = print "Usage: \n"
        in
            OS.Process.exit(OS.Process.success)
        end
    | processArgs ["g", filename, section] =
        (* Get section *)
        (parseIni o readFile) filename
    | processArgs ["g", filename, section, item] =
        (* Get item *)
        (parseIni o readFile) filename
    | processArgs ["d", filename, section] =
        (* Delete section *)
        (parseIni o readFile) filename
    | processArgs ["d", filename, section, item] =
        (* Delete item *)
        (parseIni o readFile) filename
    | processArgs ["s", filename, section, item, value] =
        (* Set value *)
        (parseIni o readFile) filename
    | processArgs _ =
        processArgs []


val args = CommandLine.arguments()
val _ = processArgs args


val filename = "test.ini"
val contents = readFile filename
    handle Error => exitWithError ("couldn't read file " ^ filename)
val _ = map (fn x => print (x ^ "\n")) contents
val _ = OS.Process.exit(OS.Process.success)
