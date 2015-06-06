(* ini_data *)

(* Model an INI file starting with key=value pairs. *)
type property = { key : string, value : string }
type section = { name : string, contents : property list }
type ini_data = section list

datatype line_token =
      PropertyLine of property
    | SectionLine of section
    | CommentLine of string
datatype operation =
      Noop
    | SelectSection of string
    | SelectProperty of { section : string, key : string }
    | RemoveSection of string
    | RemoveProperty of { section : string, key : string }
    | UpdateProperty of { section : string, key : string, newValue : string }

exception Tokenization of string

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
        val isComment = String.isPrefix ";" line
        val isSection =
            (String.isPrefix "[" line) andalso (String.isSuffix "]" line)
        val propertyFields = (String.fields (fn c => c = #"=") line)
    in
        case (line, isComment, isSection, propertyFields) of
              ("[]", _, _, _) => raise Tokenization("empty section name")
            | (_, true, _, _) => CommentLine(line)
            | (_, false, true, _) =>
                let
                    val size = String.size line
                    val sectionName = String.substring (line, 1, (size - 2))
                in
                    SectionLine { name = sectionName, contents = [] }
                end
            | (_, false, false, [key, value]) =>
                PropertyLine { key = key, value = value }
            | (_, false, false, _) =>
                raise Tokenization("invalid line: " ^ line)
    end

(* Transform a list of tokens into a simple AST for the INI file. *)
fun makeSections (lines : line_token list, acc: section list) : ini_data =
    case lines of
          [] => map
            (fn x => { name = #name x, contents = rev(#contents x) }) (rev acc)
        | SectionLine(sec)::xs =>
            makeSections(xs, sec::acc)
        | PropertyLine(prop)::xs =>
            let
                val newAcc = case acc of
                      (y : section)::(ys : section list) =>
                        { name = #name y, contents = prop::(#contents y)}::ys
                    | [] => [{ name = "", contents = [prop] }]
            in
                makeSections(xs, newAcc)
            end
        (* Skip comment lines. *)
        | CommentLine(comment)::xs => makeSections(xs, acc)

fun parseIni (lines : string list) : ini_data =
    let
        val tokenizedLines = map tokenizeLine lines
            handle Tokenization(message) => exitWithError message
    in
        makeSections(tokenizedLines, [])
    end

fun stringifySection (sec : section) : string =
    let
        val header = case #name sec of
              "" => ""
            | sectionName =>  "[" ^ sectionName ^ "]\n"
        val body = List.map
            (fn prop => (#key prop) ^ "=" ^ (#value prop)) (#contents sec)
    in
        header ^ (String.concatWith "\n" body)
    end

fun outputIni (ini : ini_data) : unit =
    let
        val sections = map stringifySection ini
    in
        print((String.concatWith "\n" sections) ^ "\n")
    end

fun matchOp (opr : operation) (sectionName : string) (key : string) : bool =
    case opr of
          Noop => true
        | SelectSection osn =>
            sectionName = osn
        | SelectProperty { section = osn, key = okey } =>
            (sectionName = osn) andalso (key = okey)
        | RemoveSection osn =>
            sectionName <> osn
        | RemoveProperty { section = osn, key = okey } =>
            (sectionName <> osn) orelse (key <> okey)
        | UpdateProperty { section = osn, key = okey, newValue = nv } =>
            (sectionName = osn) andalso (key = okey)

fun selectFromIni (opr : operation) (ini : ini_data) : ini_data =
    let
        fun selectItems (opr : operation) (sec : section) : section =
            {
                name = (#name sec),
                contents = List.filter
                    (fn prop => matchOp opr (#name sec) (#key prop))
                    (#contents sec)
            }
        val mapped = List.map (selectItems opr) ini
    in
        List.filter (fn sec => (not o null o #contents) sec) mapped
    end

(* Find replacement values in from for the existing properties in to.
 * This function makes n^2 comparisons and is hence slow. *)
fun mergeSection (from : section) (to : section) : section =
    let
        fun findReplacements (replacementSource : property list) p1 =
            let
                val replacement =
                    List.find (fn p2 => (#key p2) = (#key p1)) replacementSource
            in
                case replacement of
                      SOME(p2) => p2
                    | NONE => p1
            end
        fun missingIn (pl : property list) (p1 : property) : bool =
            not (List.exists (fn p2 => (#key p2) = (#key p1)) pl)
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
            val _ = print (
                "Usage: inifile g filename [section [key]]\n" ^
                "       inifile d filename section [key]\n" ^
                "       inifile s filename section key value\n")
        in
            OS.Process.exit(OS.Process.success)
        end
    | processArgs ["g", filename] =
        processFile (fn x => x) filename
    | processArgs ["g", filename, section] =
        (* Get section *)
        processFile (selectFromIni (SelectSection section)) filename
    | processArgs ["g", filename, section, key] =
        (* Get property *)
        let
            val q = SelectProperty { section = section, key = key }
        in
            processFile (selectFromIni q) filename
        end
    | processArgs ["d", filename, section] =
        (* Delete section *)
        processFile (selectFromIni (RemoveSection section)) filename
    | processArgs ["d", filename, section, key] =
        (* Delete property *)
        let
            val q = RemoveProperty { section = section, key = key }
        in
            processFile (selectFromIni q) filename
        end
    | processArgs ["s", filename, section, key, value] =
        (* Set value *)
        let
            val update = [{
                name = section,
                contents = [{ key = key, value = value}]
            }]
        in
            processFile (mergeIni update) filename
        end
    | processArgs _ =
        processArgs []


val args = CommandLine.arguments()
val _ = processArgs args
val _ = OS.Process.exit(OS.Process.success)
