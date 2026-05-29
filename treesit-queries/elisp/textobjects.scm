(function_definition) @function.outer

(comment)+ @comment.outer

((special_form
   . (symbol) @_name
   (#match? @_name "^defvar$")) @defvar.outer)

((special_form
   . (symbol) @_name
   (#match? @_name "^setq$")) @setq.outer)

((special_form
   . (symbol) @_name
   (#match? @_name "^let$")) @let.outer)

((special_form
   . (symbol) @_name
   (#match? @_name "^let\*$")) @let_star.outer)

((special_form
   . (symbol) @_name
   (#match? @_name "^if$")) @if.outer)

((special_form
   . (symbol) @_name
   (#match? @_name "^when$")) @when.outer)

((special_form
   . (symbol) @_name
   (#match? @_name "^unless$")) @unless.outer)
