import {parensed}      from 'basegl/lib/text/CodeGen'
import * as Reflect    from 'basegl/object/Reflect'
import * as Property   from 'basegl/object/Property'
import * as GLSL       from 'basegl/display/target/WebGL'
import * as TypeClass  from 'basegl/lib/TypeClass'



########################
### Common operators ###
########################

export defineAssocOp = (t, tc, f) =>
  TypeClass.implement t, tc, (v) ->
    switch Reflect.typeOf v
      when String then tc GLSL.toCode(@), v
      else f @, v

export defineExprOp = (tc, fn) =>
  TypeClass.implement String, tc, (v) ->
    parensed(parensed(@) + ' ' + fn + ' ' + parensed(GLSL.toCode v))

export defBinaryOp = (ts, fn, f) =>
  tc = TypeClass.define fn
  for t from ts
    defineAssocOp t, tc, f
  defineExprOp  tc, fn
  tc

export add  = defBinaryOp [Number]          , '+'  , (a,b) => a +  b
export sub  = defBinaryOp [Number]          , '-'  , (a,b) => a -  b
export mul  = defBinaryOp [Number]          , '*'  , (a,b) => a *  b
export div  = defBinaryOp [Number]          , '/'  , (a,b) => a /  b
export lt   = defBinaryOp [Number]          , '<'  , (a,b) => a <  b
export gt   = defBinaryOp [Number]          , '>'  , (a,b) => a >  b
export lte  = defBinaryOp [Number]          , '<=' , (a,b) => a <= b
export gte  = defBinaryOp [Number]          , '>=' , (a,b) => a >= b
export eq   = defBinaryOp [Number, Boolean] , '==' , (a,b) => a == b
export neq  = defBinaryOp [Number, Boolean] , '!=' , (a,b) => a != b
export and_ = defBinaryOp [Boolean]         , '&&' , (a,b) => a && b
export or_  = defBinaryOp [Boolean]         , '||' , (a,b) => a || b
export xor  = defBinaryOp [Boolean]         , '^^' , (a,b) => (a || b) && !(a && b)


# TODO: negate, not


#############################
### Common math functions ###
#############################

export bindNumFunc = (name, fnative=null) ->
  if not fnative then fnative = Math[name]
  (args...) ->
    if Reflect.areNumbers args then fnative args...
    else GLSL.call name, (GLSL.toCode arg for arg in args)

export bindNumConst = (name, fnative=null) ->
  if not fnative then fnative = Math[name]
  GLSL.toCode fnative

export abs    = bindNumFunc 'abs'
export acos   = bindNumFunc 'acos'
export asin   = bindNumFunc 'asin'
export atan   = bindNumFunc 'atan'
export atan2  = bindNumFunc 'atan2'
export ceil   = bindNumFunc 'ceil'
export cos    = bindNumFunc 'cos'
export exp    = bindNumFunc 'exp'
export floor  = bindNumFunc 'floor'
export log    = bindNumFunc 'log'
export log10  = bindNumFunc 'log10'
export max    = bindNumFunc 'max'
export min    = bindNumFunc 'min'
export mod    = bindNumFunc 'mod'
export PI     = Math.PI # bindNumConst 'PI'
export pow    = bindNumFunc 'pow'
export random = bindNumFunc 'random'
export round  = bindNumFunc 'round'
export sign   = bindNumFunc 'sign'
export sin    = bindNumFunc 'sin'
export sqrt   = bindNumFunc 'sqrt'
export tan    = bindNumFunc 'tan'
export trunc  = bindNumFunc 'trunc'
export clamp  = bindNumFunc 'clamp', (a,min=0,max=1) -> Math.min(Math.max(a, min), max);
