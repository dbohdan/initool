(* IniFile *)

(* key=value in an ini file *)
type assignment = { key : string, value : string }
type sectionContents = assignment list
type section = { name : string, contents : sectionContents }
type inifile = section list

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
fun tokenizeLine (line : string) : linetype =
    let
        val isSection =
            (String.isPrefix "[" line) andalso (String.isSuffix "]" line)
        val assignmentFields = (String.fields (fn c => c = #"=") line)
    in
        case (isSection, assignmentFields) of
              (true, _) =>
                SectionLine({ name = line, contents = [] })
            | (false, [key, value]) =>
                AssignmentLine({ key = key, value = value })
            | (false, _) =>
                raise Fail("invalid line: " ^ line)
    end

fun makeSections (lines : linetype list, acc: section list) : section list =
    case lines of
          [] => map
            (fn x => { name = #name x, contents = rev(#contents x) }) (rev acc)
        | SectionLine(section)::xs =>
            makeSections(xs, section::acc)
        | AssignmentLine(a)::xs =>
            let
                val (y : section)::(ys : section list) = acc
                val newAcc = { name = #name y, contents = a::(#contents y)}::ys
            in
                makeSections(xs, newAcc)
            end

fun parseIni (lines : string list) : inifile =
    let
        val tokenizedLines = map tokenizeLine lines
    in
        makeSections(tokenizedLines, [])
    end

fun stringifySection (sec : section) : string =
    let
        val header = #name sec
        val body = map (fn a => (#key a) ^ "=" ^ (#value a)) (#contents sec)
    in
        header ^ "\n" ^ (String.concatWith "\n" body)
    end

fun outputIni ini =
    let
        val sections = map stringifySection ini
    in
        print(String.concatWith "\n" sections)
    end
fun processArgs [] =
        let
            val _ = print("Usage: inifile command filename section " ^
                    "[item [value]] \n")
        in
            OS.Process.exit(OS.Process.success)
        end
    | processArgs ["g", filename, section] =
        (* Get section *)
        (outputIni o parseIni o readFile) filename
    | processArgs ["g", filename, section, item] =
        (* Get item *)
        (outputIni o  parseIni o readFile) filename
    | processArgs ["d", filename, section] =
        (* Delete section *)
        (outputIni o  parseIni o readFile) filename
    | processArgs ["d", filename, section, item] =
        (* Delete item *)
        (outputIni o  parseIni o readFile) filename
    | processArgs ["s", filename, section, item, value] =
        (* Set value *)
        (outputIni o  parseIni o readFile) filename
    | processArgs _ =
        processArgs []


val args = CommandLine.arguments()
val _ = processArgs args
val _ = OS.Process.exit(OS.Process.success)
