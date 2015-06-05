(* IniFile *)

(* key=value in an ini file *)
type assignment = { key : string, value : string }
type sectionContents = assignment list
type section = { name : string, contents : sectionContents }
type inifile = section list

datatype linetype = AssignmentLine of assignment | SectionLine of section
datatype query = FindEverything | FindString of string

fun readFile (filename : string) : string list =
    let
        val file = TextIO.openIn filename
        val contents = TextIO.inputAll file
        val _ = TextIO.closeIn file
    in
        String.tokens (fn c => c = #"\n") contents
    end

fun exitWithError (message : string) =
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
        | SectionLine(sec)::xs =>
            makeSections(xs, sec::acc)
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

fun outputIni (ini : inifile) : unit =
    let
        val sections = map stringifySection ini
    in
        print((String.concatWith "\n" sections) ^ "\n")
    end

fun selectAssignments (searchKey : string) (invert : bool) (al : assignment list) : assignment list =
    let
        val filterFn = fn a : assignment =>
            let
                val { key, value } = a
                val match = searchKey = key
            in
                if invert then not match else match
            end
    in
        List.filter filterFn al
    end

fun selectSection (sectionName : string) (ini : inifile) : inifile =
    List.filter (fn sec => (#name sec) = sectionName) ini

fun removeSection (sectionName : string) (ini : inifile) : inifile =
    List.filter (fn sec => (#name sec) <> sectionName) ini

fun selectItem (keyToFind : string) (sec : section) : section =
    {
        name = (#name sec),
        contents =
            List.filter (fn { key, value } => key = keyToFind) (#contents sec)
    }

fun selectItems (keyToFind : string) (ini : inifile) : inifile =
    let
        val mapped = List.map (selectItem keyToFind) ini
    in
        List.filter (fn sec => (not o null o #contents) sec) mapped
    end

fun processFile filterFn filename =
    (outputIni o filterFn o parseIni o readFile) filename

fun processArgs [] =
        let
            val _ = print("Usage: inifile command filename section " ^
                    "[item [value]] \n")
        in
            OS.Process.exit(OS.Process.success)
        end
    | processArgs ["g", filename, section] =
        (* Get section *)
        processFile (selectSection("[" ^ section ^ "]")) filename
    | processArgs ["g", filename, section, item] =
        (* Get item *)
        processFile (selectSection ("[" ^ section ^ "]") o (selectItems item)) filename
    | processArgs ["d", filename, section] =
        (* Delete section *)
        processFile (removeSection("[" ^ section ^ "]")) filename
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
