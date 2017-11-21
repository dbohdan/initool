(* initool -- manipulate the contents of INI files from the command line
 * Copyright (c) 2015, 2016, 2017 dbohdan
 * License: MIT
 *)

structure Ini :> INI =
  struct
    (* Model an INI file starting with key=value pairs. *)
    type property = { key : string, value : string }
    datatype item =
        Property of property
      | Comment of string
    type section = { name : string, contents : item list }
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
      | UpdateProperty of {
          section : string,
          key : string,
          newValue : string
        }

    exception Tokenization of string

    (* A very rough tokenizer for INI lines. *)
    fun tokenizeLine (rawLine : string) : line_token =
      let
        fun split c s =
          let
            val fields = String.fields (fn ch => ch = c) s
          in
            case fields of
                [] => []
              | x::[] => [x]
              | x::xs => [x, String.concatWith (String.str c) xs]
          end
        val trimWhitespace = StringTrim.all [" ", "\t"]
        val line = trimWhitespace rawLine
        val isComment = String.isPrefix ";" line
        val isSection =
          (String.isPrefix "[" line) andalso
          (String.isSuffix "]" line)
        val keyAndValue = List.map trimWhitespace (split #"=" line)
      in
        case (line, isComment, isSection, keyAndValue) of
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
      let
        fun addItem (newItem : item) (sl : section list) =
          case sl of
              (y : section)::ys =>
              {
                name = #name y,
                contents = newItem::(#contents y)
              }::ys
            | [] => [{ name = "", contents = [newItem] }]
      in
        case lines of
            [] => map
            (fn x => {
              name = #name x,
              contents = rev(#contents x)
            })
            (rev acc)
          | SectionLine(sec)::xs =>
            makeSections xs (sec::acc)
          | PropertyLine(prop)::xs =>
            makeSections xs (addItem (Property prop) acc)
          | CommentLine(comment)::xs =>
            makeSections xs (addItem (Comment comment) acc)
      end

    fun parse (lines : string list) : ini_data =
      let
        val tokenizedLines = map tokenizeLine lines
      in
        makeSections tokenizedLines []
      end

    fun stringifySection (sec : section) : string =
      let
        fun stringifyItem (i : item) =
          case i of
              Property prop => (#key prop) ^ "=" ^ (#value prop)
            | Comment c => c
        val header = case #name sec of
            "" => ""
          | sectionName => "[" ^ sectionName ^ "]\n"
        val body = List.map stringifyItem (#contents sec)
      in
        header ^ (String.concatWith "\n" body)
      end

    fun stringify (ini : ini_data) : string =
      let
        val sections = map stringifySection ini
      in
        (String.concatWith "\n" sections) ^ "\n"
      end

    (* Say whether the item i in section sec should be returned under
     * the operation opr.
     *)
    fun matchOp (opr : operation) (sec : section) (i : item) : bool =
      let
        val sectionName = #name sec
      in
        case (opr, i) of
            (Noop, _) => true
          | (SelectSection osn, _) =>
            sectionName = osn
          | (SelectProperty { section = osn, key = okey },
              Property { key, value = _ }) =>
            (sectionName = osn) andalso (key = okey)
          | (SelectProperty { section = osn, key = okey },
              Comment c) =>
            false
          | (RemoveSection osn, _) =>
            sectionName <> osn
          | (RemoveProperty { section = osn, key = okey },
              Property { key, value = _ }) =>
            (sectionName <> osn) orelse (key <> okey)
          | (RemoveProperty { section = osn, key = okey },
              Comment _) =>
            true
          | (UpdateProperty {
                section = osn,
                key = okey,
                newValue = nv
              }, Property { key, value = _ }) =>
            (sectionName = osn) andalso (key = okey)
          | (UpdateProperty {
                section = osn,
                key = okey,
                newValue = nv
              }, Comment _) =>
            false
      end

    fun select (opr : operation) (ini : ini_data) : ini_data =
      let
        fun selectItems (opr : operation) (sec : section) : section =
          {
            name = (#name sec),
            contents = List.filter (matchOp opr sec) (#contents sec)
          }
        val sectionsFiltered =
          case opr of
            SelectSection osn =>
            List.filter (fn sec => (#name sec) = osn) ini
          | SelectProperty { section = osn, key = _ } =>
            List.filter (fn sec => (#name sec) = osn) ini
          | RemoveSection osn =>
            List.filter (fn sec => (#name sec) <> osn) ini
          | _ => ini
      in
        List.map (selectItems opr) sectionsFiltered
      end

    (* Find replacement values in from for the existing properties in to.
     * This function makes n^2 comparisons and is hence slow.
     *)
    fun mergeSection (from : section) (to : section) : section =
      let
        fun itemsEqual (i1 : item) (i2 : item) =
          case (i1, i2) of
              (Property p1, Property p2) => (#key p2) = (#key p1)
            | (_, _) => false
        fun findReplacements (replacementSource : item list) p1 =
          let
            val replacement =
              List.find (itemsEqual p1) replacementSource
          in
            case replacement of
                SOME(p2) => p2
              | NONE => p1
          end
        fun missingIn (pl : item list) (p1 : item) : bool =
          not (List.exists (itemsEqual p1) pl)
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
