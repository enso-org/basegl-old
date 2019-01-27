
import * as glsl from 'basegl/data/vector'
import {int, float} from 'basegl/data/vector'





# class Float
#   constructor: (@val) ->
#     @type = 'float'
#   show: ->
#     if @val % 1 == 0 then "#{@val}.0" else "#{val}"
# float = (val) -> new Float val

# class Int
#   constructor: (@val) ->
#     @type = 'int'
#   show: -> "#{Math.round(val)}"
# int = (val) -> new Int val


class Scope
  constructor: ->
    @_scope       = new Map
    @_parentScope = null

  lookupScope: (name) -> 
    val = @_scope.get name
    if val?
      return val
    else
      return @_parentScope?.lookupScope name

  addToScope: (name, val) ->
    @_scope.set name, val

  withParentScope: (scope, f) ->
    parentScope = @_parentScope
    @_parentScope = scope
    out = f()
    @_parentScope = parentScope
    return out

  value: (a) ->
    switch a.constructor
      when Number then float a
      when String
        type = @lookupScope a
        if not type?
          throw "Variable '#{a}' not found in scope"
        new Alias a, type
      else a

  
    

class App
  constructor: (@name, @args) ->
app = (name, args) -> new App name, args

class Assignment
  constructor: (@name, @val) ->
assignment = (name, val) -> new Assignment name, val

# fn = (name) -> (args...) -> app name, args

class Alias
  constructor: (@name, @type) ->
  toGLSL: -> @name


seq = (f) -> 
  s = new Seq
  f.call s
  s

class Seq extends Scope
  constructor: ->
    super()
    @exprs = []

  def: (name, val) ->
    @exprs.push (assignment name, val)

  toGLSL: ->
    lines = []
    for expr in @exprs
      switch expr.constructor
        when Assignment
          name   = expr.name
          val    = @value(expr.val)
          type   = val.type
          exType = @lookupScope name
          if exType?
            if exType != type
              # throw "Type missmatch: #{exType.gl.name} /= #{type.gl.name}"
              lines.push "#{name} = #{exType.gl.name}(#{val.toGLSL()});"
            else
              lines.push "#{name} = #{val.toGLSL()};"
          else
            @addToScope name, type
            lines.push "#{type.gl.name} #{name} = #{val.toGLSL()};"
           
    lines.join '\n'


block = (f) -> 
  seq   = new Seq
  proxy = new Proxy {}, 
    get: (obj, name) -> name
    set: (obj, name, val) ->
      seq.def name, val
      return true
  f.call proxy
  seq



class Fn extends Scope
  constructor: (@name, @types, f) ->
    super()
    match = f.toString().match(/function\s*\((.*)\)\s*{/m)
    @args = (arg.trim() for arg in match[1].split(','))
    if @args.length != @types.length
      throw "Types number does not match argument number"
    @localScope = new Map 
    for i in [0...@args.length]
      @addToScope @args[i], @types[i]

    localArgs = @args
    do (localArgs) =>
      @body = block -> f.call @, localArgs...
    console.log @body

  toGLSL: ->
    body   = @body.withParentScope @, => @body.toGLSL()
    header = "#{name} () {\n#{body}\n}"
    header
    

fn = (name, types, f) -> new Fn name, types, f

class Builder
  constructor: ->
    @decls = []

  fn: (name, types, f) ->
    decl = fn name, types, f
    @decls.push decl

  toGLSL: -> 
    (decl.toGLSL() for decl in @decls).join('\n\n')


builder = (f) ->
  bldr = new Builder
  f.call bldr
  bldr


class Typed


# x = block ->
#   @x = 1
#   @x = int(2)


# x = builder ->
#   @fn "testx", [float, int, int], (ala,ola,mola) ->
#     @x = ola

# console.log x.toGLSL()



# shapeTrans = (name,f) ->
#   @fn name, [vec2], (origin) -> f()


# move = (target, source, args...) ->
#   shapeTrans.call @, target, 