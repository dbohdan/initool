(* IniFile *)

(* key=value in an ini file *)
type assignment = { key : string, value : string }
type sectionContents = assignment list
type section = { name : string, contents : sectionContents }
type inifile = section list

datatype linetype = AssignmentLine of assignment | SectionLine of section
datatype query = Everything | With of string | Without of string

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

fun matchQuery (q: query) (value: string) : bool =
    case q of
          Everything => true
        | With(s) => value = s
        | Without(s) => value <> s

fun selectItem (keyToFind : query) (valueToFind : query) (sec : section) : section =
    let
        val filterFn = fn { key, value } =>
            (matchQuery keyToFind key) andalso (matchQuery valueToFind value)
    in
        {
            name = (#name sec),
            contents = List.filter filterFn (#contents sec)
        }
    end

fun selectFromIni (section : query) (key : query) (value : query) (ini : inifile) : inifile =
    let
        val selectedSections =
            List.filter (fn sec => matchQuery section (#name sec)) ini
        val mapped = List.map (selectItem key value) selectedSections
    in
        List.filter (fn sec => (not o null o #contents) sec) mapped
    end

(* Find replacement values in repl for the existing items in src.
 * This function makes n^2 comparisons and is hence slow. *)
(* TODO: Make this merge new items. *)
fun mergeSection (repl: section) (src: section) : section =
    let
        fun findReplacements (replacementSource : assignment list) a1 =
            let
                val replacement =
                    List.find (fn a2 => (#key a2) = (#key a1)) replacementSource
            in
                case replacement of
                      SOME(a2) => a2
                    | NONE => a1
            end
        val updatedItems =
            List.map (findReplacements (#contents repl)) (#contents src)
    in
        { name = (#name src), contents = updatedItems }
    end

(* This function makes n^2 comparisons and is hence slow. *)
(* TODO: Make this merge new sections. *)
fun mergeIni (repl: inifile) (src: inifile) : inifile =
    let
        fun mergeOrKeep oldSec =
            let
                val counterpart =
                    List.find (fn newSec => (#name newSec) = (#name oldSec)) repl
            in
                case counterpart of
                      SOME(newSec) => mergeSection newSec oldSec
                    | NONE => oldSec
            end

        val updatedIni = List.map mergeOrKeep src
    in
        updatedIni
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
        processFile
            (selectFromIni
                (With ("[" ^ section ^ "]")) Everything Everything)
            filename
    | processArgs ["g", filename, section, item] =
        (* Get item *)
        processFile
            (selectFromIni
                (With ("[" ^ section ^ "]")) (With item) Everything)
            filename
    | processArgs ["d", filename, section] =
        (* Delete section *)
        processFile
            (selectFromIni
                (Without ("[" ^ section ^ "]")) Everything Everything)
            filename
    | processArgs ["d", filename, section, item] =
        (* Delete item *)
        (* FIXME *)
        processFile
            (selectFromIni
                (With ("[" ^ section ^ "]")) (Without item) Everything)
            filename
    | processArgs ["s", filename, section, item, value] =
        (* Set value *)
        let
            val update = [{
                name = "[" ^ section ^ "]",
                contents = [{ key = item, value = value}]
            }]
        in
            processFile (mergeIni update) filename
        end
    | processArgs _ =
        processArgs []


val args = CommandLine.arguments()
val _ = processArgs args
val _ = OS.Process.exit(OS.Process.success)
