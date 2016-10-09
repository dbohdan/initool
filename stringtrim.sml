(* initool -- manipulate the contents of INI files from the command line
 * Copyright (c) 2015, 2016 dbohdan
 * License: MIT
 *)

structure StringTrim =
  struct
    fun left (prefix : string) (s : string) : string =
      if String.isPrefix prefix s then
        let
          val len = String.size prefix
        in
          left prefix (String.extract (s, len, NONE))
        end
      else s

    fun right (suffix : string) (s : string) : string =
      if String.isSuffix suffix s then
        let
          val len = String.size suffix
          val total = String.size s
        in
          right suffix (String.extract (s, 0, SOME(total - len)))
        end
      else s

    fun both (s1 : string) (s2 : string) : string =
      (left s1 o right s1) s2

    fun all (l : string list) (s : string) : string =
      let
        fun applyAll (fl : ('a -> 'a) list) (x : 'a) =
          case fl of
              [] => x
            | f::fs => applyAll fs (f x)
        val funs = List.map both l
        val trimmed = applyAll funs s
      in
        if trimmed = s then s else all l trimmed
      end
  end
