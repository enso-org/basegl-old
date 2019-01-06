import * as Property  from 'basegl/object/Property'
import * as Reflect   from 'basegl/object/Reflect'
import * as TypeClass from 'basegl/lib/TypeClass'


#######################
### GLSL Primitives ###
#######################

export class Expr
  constructor: (@expr, @type=null) ->

  declaration: (name) ->
    "#{@type} #{name} = #{expr};"

export expr     = Property.consAlias Expr
export callExpr = (type, args) -> expr (call type, args), type
export call     = (func, args) -> func + '(' + args.join(',') + ')'
export callRec  = (func, args) -> callRecBase func, args[0], args.slice(1)
export callRecBase = (func, base, args) ->
  out = call func, [base, args[0]]
  if args.length > 1 then out = callRecBase func, out, args.slice(1)
  out
# export callRecR = (func, args) ->
#   if args.length == 2 then call func, args
#   else call func, [args[0], (callRec func, args.slice(1))]


### GLSL value / expr ###
export toExpr = TypeClass.define('toExpr')
export toCode = (obj, args...) -> (toExpr obj, args...).expr
TypeClass.implement Number  , toExpr, -> expr (if Reflect.isIntegral @ then @ + '.0' else @.toString()), 'float'
TypeClass.implement Boolean , toExpr, -> expr @.toString(), 'bool'
TypeClass.implement String  , toExpr, -> expr @
