signature INI =
  sig
    type property = {key:string, value:string}
    datatype item =
        Property of property
      | Comment of string
    type section = {contents:item list, name:string}
    type ini_data = section list
    datatype line_token =
        CommentLine of string
      | PropertyLine of property
      | SectionLine of section
    datatype operation =
        Noop
      | RemoveProperty of {key:string, section:string}
      | RemoveSection of string
      | SelectProperty of {key:string, section:string}
      | SelectSection of string
      | UpdateProperty of {key:string, newValue:string, section:string}
    exception Tokenization of string
    val tokenizeLine : string -> line_token
    val makeSections : line_token list
      -> section list
      -> {contents:item list, name:string} list
    val parse : string list -> ini_data
    val stringifySection : section -> string
    val stringify : ini_data -> string
    val matchOp : operation -> section -> item -> bool
    val select : operation -> ini_data -> ini_data
    val mergeSection : section -> section -> section
    val merge : ini_data -> ini_data -> ini_data
  end
