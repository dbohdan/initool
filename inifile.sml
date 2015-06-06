(* ini_data *)

(* Model an INI file starting with key=value pairs. *)
type assignment = { key : string, value : string }
type section = { name : string, contents : assignment list }
type ini_data = section list

datatype line_token = AssignmentLine of assignment | SectionLine of section
datatype query = Everything | With of string | Without of string

fun readLines (filename : string) : string list =
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
fun tokenizeLine (line : string) : line_token =
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

(* Transform a list of tokens into a simple AST for the INI file. *)
fun makeSections (lines : line_token list, acc: section list) : ini_data =
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

fun parseIni (lines : string list) : ini_data =
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

fun outputIni (ini : ini_data) : unit =
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

fun selectFromIni (section : query) (key : query) (value : query) (ini : ini_data) : ini_data =
    let
        val selectedSections =
            List.filter (fn sec => matchQuery section (#name sec)) ini
        val mapped = List.map (selectItem key value) selectedSections
    in
        List.filter (fn sec => (not o null o #contents) sec) mapped
    end

(* Find replacement values in from for the existing items in to.
 * This function makes n^2 comparisons and is hence slow. *)
fun mergeSection (from : section) (to : section) : section =
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
        fun missingIn (al : assignment list) (a1 : assignment) : bool =
            not (List.exists (fn a2 => (#key a2) = (#key a1)) al)
        val updatedItems =
            List.map (findReplacements (#contents from)) (#contents to)
        val newItems =
            List.filter (missingIn updatedItems) (#contents from)
        val mergedItems = updatedItems @ newItems
    in
        { name = (#name to), contents = mergedItems }
    end

(* This function makes n^2 comparisons and is hence slow. *)
fun mergeIni (from: ini_data) (to: ini_data) : ini_data =
    let
        fun mergeOrKeep sec1 =
            let
                val secToMerge =
                    List.find (fn sec2 => (#name sec2) = (#name sec1)) from
            in
                case secToMerge of
                      SOME(sec2) => mergeSection sec2 sec1
                    | NONE => sec1
            end
        fun missingIn (ini : ini_data) (sec1 : section) : bool =
            not (List.exists (fn sec2 => (#name sec2) = (#name sec1)) ini)

        val updatedIni = List.map mergeOrKeep to
        val newSections = List.filter (missingIn updatedIni) from
    in
        updatedIni @ newSections
    end

fun processFile filterFn filename =
    (outputIni o filterFn o parseIni o readLines) filename

fun processArgs [] =
        let
            val _ = print("Usage: ini_data command filename [section " ^
                    "[item [value]]] \n")
        in
            OS.Process.exit(OS.Process.success)
        end
    | processArgs ["g", filename] =
        processFile (fn x => x) filename
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
