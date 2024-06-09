(* initool -- manipulate the contents of INI files from the command line
 * Copyright (c) 2015-2018, 2023-2024 D. Bohdan
 * License: MIT
 *)

structure Id =
struct
  (* A section or key identifier. *)
  datatype id =
    StrId of string
  | Wildcard

  val empty = StrId ""

  type options = {ignoreCase: bool}

  fun normalize (opts: options) (StrId s) =
        if #ignoreCase opts then StrId (String.map Char.toLower s) else StrId s
    | normalize opts Wildcard = Wildcard

  fun same (opts: options) (a: id) (b: id) : bool =
    let in
      case (a, b) of
        (Wildcard, _) => true
      | (_, Wildcard) => true
      | _ => (normalize opts a) = (normalize opts b)
    end

  fun fromString s = StrId s

  fun fromStringWildcard "*" = Wildcard
    | fromStringWildcard "_" = Wildcard
    | fromStringWildcard s =
        if String.isPrefix "\\" s then StrId (String.extract (s, 1, NONE))
        else StrId s

  fun toString id' =
    case id' of
      StrId s => s
    | Wildcard => "*"
end

structure Ini =
struct
  (* Model an INI file starting with key=value pairs. *)
  type property = {key: Id.id, value: string}
  datatype item =
    Property of property
  | Empty
  | Comment of string
  | Verbatim of string
  type section = {name: Id.id, contents: item list}
  type ini_data = section list

  datatype line_token =
    CommentLine of string
  | EmptyLine
  | PropertyLine of property
  | SectionLine of section
  | VerbatimLine of string

  datatype operation =
    Noop
  | SelectSection of Id.id
  | SelectProperty of {section: Id.id, key: Id.id, pattern: Id.id}
  | RemoveSection of Id.id
  | RemoveProperty of {section: Id.id, key: Id.id}
  | ReplaceInValue of
      {section: Id.id, key: Id.id, pattern: Id.id, replacement: string}

  exception Tokenization of string

  (* A rough tokenizer for INI lines. *)
  fun tokenizeLine (passThrough: bool) (rawLine: string) : line_token =
    let
      fun split c s =
        let
          val fields = String.fields (fn ch => ch = c) s
        in
          case fields of
            [] => []
          | x :: [] => [x]
          | x :: xs => [x, String.concatWith (String.str c) xs]
        end
      val trimWhitespace = StringTrim.all [" ", "\t"]
      val line = trimWhitespace rawLine
      val isComment =
        (String.isPrefix ";" line) orelse (String.isPrefix "#" line)
      val isSection =
        (String.isPrefix "[" line) andalso (String.isSuffix "]" line)
      val keyAndValue = List.map trimWhitespace (split #"=" line)
    in
      case (line, isComment, isSection, keyAndValue) of
        ("[]", _, _, _) =>
          if passThrough then VerbatimLine "[]"
          else raise Tokenization ("empty section name")
      | (_, true, _, _) => CommentLine (line)
      | (_, false, true, _) =>
          let
            val size = String.size line
            val sectionName = String.substring (line, 1, size - 2)
          in
            SectionLine {name = Id.fromString sectionName, contents = []}
          end
      | ("", false, false, _) => EmptyLine
      | (_, false, false, key :: value) =>
          (case value of
             [] =>
               if passThrough then VerbatimLine line
               else raise Tokenization ("invalid line: \"" ^ line ^ "\"")
           | _ =>
               PropertyLine
                 {key = Id.fromString key, value = String.concatWith "=" value})
      | (_, false, false, _) =>
          raise Tokenization
            ("this should never be reached; line: \"" ^ line ^ "\"")
    end

  (* Transform a list of tokens into a simple AST for the INI file. *)
  fun makeSections (lines: line_token list) (acc: section list) : ini_data =
    let
      fun addItem (newItem: item) (sl: section list) =
        case sl of
          (y: section) :: ys =>
            {name = #name y, contents = newItem :: (#contents y)} :: ys
        | [] => [{name = Id.fromString "", contents = [newItem]}]
    in
      case lines of
        [] =>
          map (fn x => {name = #name x, contents = rev (#contents x)}) (rev acc)
      | SectionLine (sec) :: xs => makeSections xs (sec :: acc)
      | PropertyLine (prop) :: xs =>
          makeSections xs (addItem (Property prop) acc)
      | CommentLine (comment) :: xs =>
          makeSections xs (addItem (Comment comment) acc)
      | EmptyLine :: xs => makeSections xs (addItem Empty acc)
      | VerbatimLine (comment) :: xs =>
          makeSections xs (addItem (Verbatim comment) acc)
    end

  fun parse (passThrough: bool) (lines: string list) : ini_data =
    let val tokenizedLines = map (tokenizeLine passThrough) lines
    in makeSections tokenizedLines []
    end

  fun stringifySection (sec: section) : string =
    let
      fun stringifyItem (i: item) =
        case i of
          Property prop => Id.toString (#key prop) ^ "=" ^ (#value prop)
        | Comment c => c
        | Empty => ""
        | Verbatim s => s
      val header =
        case Id.toString (#name sec) of
          "" => ""
        | sectionName => "[" ^ sectionName ^ "]\n"
      val body = List.map stringifyItem (#contents sec)
    in
      header ^ (String.concatWith "\n" body)
    end

  fun stringify (ini: ini_data) : string =
    let
      val sections = map stringifySection ini
      val concat = String.concatWith "\n" sections
    in
      if concat = "" then "" else concat ^ "\n"
    end

  fun findSubstring (matcher: string -> string -> bool) (needle: string)
    (haystack: string) (start: int) : (int * int) option =
    let
      val needleSize = String.size needle
      val haystackSize = String.size haystack
    in
      if needleSize = 0 andalso haystackSize = 0 then
        SOME (0, 0)
      else if needleSize = 0 orelse start + needleSize > haystackSize then
        NONE
      else if matcher needle (String.substring (haystack, start, needleSize)) then
        SOME (start, needleSize)
      else
        findSubstring matcher needle haystack (start + 1)
    end

  fun hasSubstring (matcher: string -> string -> bool) (needle: string)
    (haystack: string) : bool =
    Option.isSome (findSubstring matcher needle haystack 0)

  fun replace (matcher: string -> string -> bool) (pattern: Id.id)
    (replacement: string) (haystack: string) : string =
    case pattern of
      Id.Wildcard => replacement
    | Id.StrId needle =>
        case findSubstring matcher needle haystack 0 of
          NONE => haystack
        | SOME (i, needleSize) =>
            let
              val before' = String.substring (haystack, 0, i)
              val haystackSize = String.size haystack
              val after = String.extract (haystack, i + needleSize, NONE)
            in
              before' ^ replacement ^ after
            end

  (* Say whether the item i in section sec should be returned under
   * the operation opr.
   *)
  fun matchOp (opts: Id.options) (opr: operation) (sec: section) (i: item) :
    item option =
    let
      val sectionName = #name sec
      val matches = Id.same opts
      val matcher = (fn a => fn b => matches (Id.StrId a) (Id.StrId b))
    in
      case (opr, i) of
        (Noop, _) => SOME i
      | (SelectSection osn, _) =>
          if matches osn sectionName then SOME i else NONE
      | ( SelectProperty {section = osn, key = okey, pattern = pattern}
        , Property {key, value}
        ) =>
          if
            matches osn sectionName andalso matches okey key
            andalso
            (case pattern of
               Id.Wildcard => true
             | Id.StrId substring => hasSubstring matcher substring value)
          then SOME i
          else NONE
      | (SelectProperty {section = _, key = _, pattern = _}, Comment _) => NONE
      | (SelectProperty {section = _, key = _, pattern = _}, Empty) => NONE
      | (SelectProperty {section = _, key = _, pattern = _}, Verbatim _) => NONE
      | (RemoveSection osn, _) =>
          if matches osn sectionName then NONE else SOME i
      | (RemoveProperty {section = osn, key = okey}, Property {key, value = _}) =>
          if matches osn sectionName andalso matches okey key then NONE
          else SOME i
      | (RemoveProperty {section = _, key = _}, Comment _) => SOME i
      | (RemoveProperty {section = _, key = _}, Empty) => SOME i
      | (RemoveProperty {section = _, key = _}, Verbatim _) => SOME i
      | ( ReplaceInValue
            { section = osn
            , key = okey
            , pattern = pattern
            , replacement = replacement
            }
        , Property {key, value}
        ) =>
          if matches osn sectionName andalso matches okey key then
            SOME (Property
              {key = key, value = replace matcher pattern replacement value})
          else
            SOME i
      | ( ReplaceInValue {section = _, key = _, pattern = _, replacement = _}
        , Comment _
        ) => SOME i
      | ( ReplaceInValue {section = _, key = _, pattern = _, replacement = _}
        , Empty
        ) => SOME i
      | ( ReplaceInValue {section = _, key = _, pattern = _, replacement = _}
        , Verbatim _
        ) => SOME i
    end

  fun select (opts: Id.options) (opr: operation) (ini: ini_data) : ini_data =
    let
      fun selectItems (opr: operation) (sec: section) : section =
        { name = (#name sec)
        , contents = List.mapPartial (matchOp opts opr sec) (#contents sec)

        }
      val sectionsFiltered =
        case opr of
          SelectSection osn =>
            List.filter (fn sec => Id.same opts osn (#name sec)) ini
        | SelectProperty {section = osn, key = _, pattern = _} =>
            List.filter (fn sec => Id.same opts osn (#name sec)) ini
        | RemoveSection osn =>
            List.filter (fn sec => not (Id.same opts osn (#name sec))) ini
        | _ => ini
    in
      List.map (selectItems opr) sectionsFiltered
    end

  (* Find replacement values in from for the existing properties in to.
   * This function makes n^2 comparisons and is hence slow.
   *)
  fun mergeSection (opts: Id.options) (from: section) (to: section) : section =
    let
      fun itemsEqual (i1: item) (i2: item) : bool =
        case (i1, i2) of
          (Property p1, Property p2) => Id.same opts (#key p2) (#key p1)
        | (_, _) => false
      fun findReplacements (replacementSource: item list) i1 =
        let
          val replacement: item option =
            List.find (itemsEqual i1) replacementSource
        in
          case (replacement, i1) of
            (SOME (Property new), Property orig) =>
              (* Preserve the original key, which may differ in case. *)
              Property {key = #key orig, value = #value new}

          | (SOME other, _) => other
          | (NONE, _) => i1
        end
      fun missingIn (items: item list) (i1: item) : bool =
        not (List.exists (itemsEqual i1) items)
      fun addBeforeEmpty (from: item list) (to: item list) : item list =
        let
          fun emptyCount l i =
            case l of
              Empty :: xs => emptyCount xs (i + 1)
            | _ => i
          val revTo = List.rev to
          val revToEmptyCount = emptyCount revTo 0
        in
          List.rev (List.drop (revTo, revToEmptyCount)) @ from
          @ List.take (revTo, revToEmptyCount)
        end
      val updatedItems =
        List.map (findReplacements (#contents from)) (#contents to)
      val newItems = List.filter (missingIn updatedItems) (#contents from)
      val mergedItems = addBeforeEmpty newItems updatedItems
    in
      {name = (#name to), contents = mergedItems}
    end

  (* This function makes n^2 comparisons and is hence slow. *)
  fun merge (opts: Id.options) (from: ini_data) (to: ini_data) : ini_data =
    let
      fun mergeOrKeep sec1 =
        let
          val secToMerge =
            List.find (fn sec2 => Id.same opts (#name sec2) (#name sec1)) from
        in
          case secToMerge of
            SOME (sec2) => mergeSection opts sec2 sec1
          | NONE => sec1
        end
      fun missingIn (ini: ini_data) (sec1: section) : bool =
        not
          (List.exists (fn sec2 => Id.same opts (#name sec2) (#name sec1)) ini)

      val updatedIni = List.map mergeOrKeep to
      val newSections = List.filter (missingIn updatedIni) from
      val prepend = List.find (fn sec => #name sec = Id.empty) newSections
      val append = List.filter (fn sec => #name sec <> Id.empty) newSections
      val prependPadded =
        case prepend of
          NONE => []
        | SOME (prependSec) =>
            (* Add an empty line after top-level properties if there are
            * sections following them. *)
            if updatedIni <> [] orelse append <> [] then
              [{ name = (#name prependSec)
               , contents = (#contents prependSec) @ [Empty]
               }]
            else
              [prependSec]
    in
      prependPadded @ updatedIni @ append
    end

  fun sectionExists (opts: Id.options) (section: Id.id) (ini: ini_data) =
    let val q = SelectSection section
    in select opts q ini <> []
    end

  fun propertyExists (opts: Id.options) (section: Id.id) (key: Id.id)
    (pattern: Id.id) (ini: ini_data) =
    let
      val q = SelectProperty {section = section, key = key, pattern = pattern}
      val sections = select opts q ini
    in
      List.exists
        (fn {contents = (Property _ :: _), name = _} => true | _ => false)
        sections
    end

  fun removeEmptySections (sections: ini_data) =
    List.filter (fn {contents = [], name = _} => false | _ => true) sections
end
