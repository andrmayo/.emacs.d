(comment)+ @comment.outer

(source
 (list_lit) @toplevel.outer)

(list_lit (defun_header)) @function.outer

(defun_header
  function_name: (sym_lit) @function_name.outer)

(defun_header
 lambda_list: (list_lit) @lambda_list.outer)

((list_lit
 . (sym_lit) @_name
 (#match? @_name "^defstruct$")) @defstruct.outer)

((list_lit
  . (sym_lit) @_name
  (#match? @_name "^defclass$")) @defclass.outer)

((list_lit
  . (sym_lit) @_name
  (#match? @_name "^defmacro$")) @defmacro.outer)

((list_lit
   . (sym_lit) @_name
   (#match? @_name "^defparameter$")) @defparameter.outer)

((list_lit
  . (sym_lit) @_name
  (#match? @_name "^defconstant$")) @defconstant.outer)

((list_lit
  . (sym_lit) @_name
  (#match? @_name "^declare$")) @declare.outer)

((list_lit
  . (sym_lit) @_name
  (#match? @_name "^declaim$")) @declaim.outer)

((list_lit
   . (sym_lit) @_name
   (#match? @_name "^defvar$")) @defvar.outer)

((list_lit
   . (sym_lit) @_name
   (#match? @_name "^setf$")) @setf.outer)

((list_lit
   . (sym_lit) @_name
   (#match? @_name "^setq$")) @setq.outer)

((list_lit
   . (sym_lit) @_name
   (#match? @_name "^let$")) @let.outer)

((list_lit
   . (sym_lit) @_name
   (#match? @_name "^let\*$")) @let_star.outer)

((list_lit
   . (sym_lit) @_name
   (#match? @_name "^if$")) @if.outer)

((list_lit
   . (sym_lit) @_name
   (#match? @_name "^when$")) @when.outer)

((list_lit
   . (sym_lit) @_name
   (#match? @_name "^unless$")) @unless.outer)

((list_lit
   . (sym_lit) @_name
   (#match? @_name "^cond$")) @cond.outer)

((list_lit
   . (sym_lit) @_name
   (#match? @_name "^case$")) @case.outer)

((list_lit
   . (sym_lit) @_name
   (#match? @_name "^dolist$")) @dolist.outer)

((list_lit
   . (sym_lit) @_name
   (#match? @_name "^dotimes$")) @dotimes.outer)

((list_lit
   . (sym_lit) @_name
   (#match? @_name "^loop$")) @loop.outer)

((list_lit
   . (sym_lit) @_name
   (#match? @_name "^flet$")) @flet.outer)

((list_lit
   . (sym_lit) @_name
   (#match? @_name "^labels$")) @labels.outer)

((list_lit
   . (sym_lit) @_name
   (#match? @_name "^progn$")) @progn.outer)

((list_lit
   . (sym_lit) @_name
   (#match? @_name "^multiple-value-bind$")) @multiple_value_bind.outer)





