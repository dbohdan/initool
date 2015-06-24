(* initool -- manipulate the contents of INI files from the command line
 * Copyright (C) 2015 Danyil Bohdan
 * License: MIT
 *)

structure Ini :> INI =
    struct
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
            | UpdateProperty of { section : string, key : string,
                                  newValue : string }

        exception Tokenization of string

        (* A very rough tokenizer for INI lines. *)
        fun tokenizeLine (rawLine : string) : line_token =
            let
                val trimWhitespace = StringTrim.all [" ", "\t"]
                val line = trimWhitespace rawLine
                val isComment = String.isPrefix ";" line
                val isSection =
                    (String.isPrefix "[" line) andalso
                    (String.isSuffix "]" line)
                val fieldsWithWhitespace = String.fields (fn c => c = #"=") line
                val propertyFields =
                    List.map trimWhitespace fieldsWithWhitespace
            in
                case (line, isComment, isSection, propertyFields) of
                      ("[]", _, _, _) =>
                        raise Tokenization("empty section name")
                    | (_, true, _, _) => CommentLine(line)
                    | (_, false, true, _) =>
                        let
                            val size = String.size line
                            val sectionName =
                                String.substring (line, 1, (size - 2))
                        in
                            SectionLine { name = sectionName, contents = [] }
                        end
                    | (_, false, false, key::value) =>
                        (case value of
                              [] => raise Tokenization("invalid line: " ^ line)
                            | _ => PropertyLine {
                                key = key,
                                value = String.concatWith "=" value
                            })
                    | (_, false, false, _) =>
                        raise Tokenization("invalid line: " ^ line)
            end

        (* Transform a list of tokens into a simple AST for the INI file. *)
        fun makeSections (lines : line_token list)
                         (acc : section list) : ini_data =
            case lines of
                  [] => map
                    (fn x => { name = #name x, contents = rev(#contents x) })
                    (rev acc)
                | SectionLine(sec)::xs =>
                    makeSections xs (sec::acc)
                | PropertyLine(prop)::xs =>
                    let
                        val newAcc = case acc of
                              (y : section)::(ys : section list) =>
                                { name = #name y,
                                  contents = prop::(#contents y) }::ys
                            | [] => [{ name = "", contents = [prop] }]
                    in
                        makeSections xs newAcc
                    end
                (* Skip comment lines. *)
                | CommentLine(comment)::xs => makeSections xs acc

        fun parse (lines : string list) : ini_data =
            let
                val tokenizedLines = map tokenizeLine lines
            in
                makeSections tokenizedLines []
            end

        fun stringifySection (sec : section) : string =
            let
                val header = case #name sec of
                      "" => ""
                    | sectionName => "[" ^ sectionName ^ "]\n"
                val body = List.map
                    (fn prop => (#key prop) ^ "=" ^ (#value prop))
                    (#contents sec)
            in
                header ^ (String.concatWith "\n" body)
            end

        fun stringify (ini : ini_data) : string =
            let
                val sections = map stringifySection ini
            in
                (String.concatWith "\n" sections) ^ "\n"
            end

        fun matchOp (opr : operation) (sectionName : string)
                    (key : string) : bool =
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

        fun select (opr : operation) (ini : ini_data) : ini_data =
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
         * This function makes n^2 comparisons and is hence slow.
         *)
        fun mergeSection (from : section) (to : section) : section =
            let
                fun findReplacements (replacementSource : property list) p1 =
                    let
                        val replacement =
                            List.find (fn p2 => (#key p2) = (#key p1))
                                      replacementSource
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
        fun merge (from: ini_data) (to: ini_data) : ini_data =
            let
                fun mergeOrKeep sec1 =
                    let
                        val secToMerge =
                            List.find (fn sec2 => (#name sec2) = (#name sec1))
                            from
                    in
                        case secToMerge of
                              SOME(sec2) => mergeSection sec2 sec1
                            | NONE => sec1
                    end
                fun missingIn (ini : ini_data) (sec1 : section) : bool =
                    not (List.exists
                        (fn sec2 => (#name sec2) = (#name sec1)) ini)

                val updatedIni = List.map mergeOrKeep to
                val newSections = List.filter (missingIn updatedIni) from
            in
                updatedIni @ newSections
            end
    end
