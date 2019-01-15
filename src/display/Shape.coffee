import {styleMixin}           from 'basegl/display/DisplayObject'
import {consAlias}            from 'basegl/object/Property'
import {vector, point}        from 'basegl/math/Vector'
import {Composable}           from "basegl/object/Property"
import {eventDispatcherMixin} from "basegl/event/EventDispatcher"


import * as M          from 'basegl/math/Common'
import * as Color      from 'basegl/display/Color'
import * as GLSL       from 'basegl/display/target/WebGL'
import * as TypeClass  from 'basegl/lib/TypeClass'

import {parensed, glslCall} from 'basegl/lib/text/CodeGen'


### Shaders ###
import vertexHeader   from 'basegl/lib/shader/component/vertexHeader'
import vertexBody     from 'basegl/lib/shader/component/vertexBody'
import fragmentHeader from 'basegl/lib/shader/component/fragmentHeader'
import fragmentRunner from 'basegl/lib/shader/component/fragmentRunner'
import fragment_lib   from 'basegl/lib/shader/sdf/sdf'



##################
### SDF Canvas ###
##################

# defCdC = Color.rgb [1,0,0,1]
# defCd  = "rgb2lch(#{GLSL.toCode defCdC})"
# defCd  = "(#{GLSL.toCode defCdC})"

# export class CanvasShape
#   constructor: (@shapeNum, @id) ->
#     @name     = "shape_#{@shapeNum}"
#     @distance = "#{@name}_distance"
#     @id       = "#{@name}_id"
#     @bbox     = "#{@name}_bbox"
#     @color    = "#{@name}_color"
#     @density  = "#{@name}_density"


class CanvasShape2
  constructor: (@name, @id) ->

canvasShape = (name, id) -> new CanvasShape2 name, id




toShapeCode = (a) -> 
  if a instanceof CanvasShape2
    return "f_#{a.name}(origin)"
  else
    return GLSL.toCode a

toConvexHullCode = (a) -> 
  if a instanceof CanvasShape2
    return "#{a.name}_convex_hull(origin,dir,offset)"
  else
    return GLSL.toCode a

toShapeArgs = (args) ->
  (toShapeCode arg for arg in args).join(',')

toConvexHullArgs = (args) ->
  (toConvexHullCode arg for arg in args).join(',')


assembleCode = (a) ->
  if not a?
    return ''
  if a.constructor == Array
    return '\n    ' + a.join('\n    ') + '\n'
  else if a.constructor == String
    return a
  else
    return null

getCodeCfg = (a) ->
  if not a?
    return
      shape:      []
      convexHull: []
  if a.constructor == Array
    return
      shape:      a.slice()
      convexHull: a.slice()
  if a.constructor == String
    return
      shape:      [a]
      convexHull: [a]
  if a.constructor == Object
    return
      shape:      toCodeArray(a.shape)      ? []
      convexHull: toCodeArray(a.convexHull) ? []
  null

mergeCodes = (code1, code2) ->
  if not code1?
    return code2
  if not code2? 
    return code1
  code1 = getCodeCfg code1
  code2 = getCodeCfg code2
  return 
    shape:      code1.shape.concat      code2.shape
    convexHull: code1.convexHull.concat code2.convexHull



toCodeArray = (a) ->
  if not a? 
    return []
  if a.constructor == Array
    return a
  if a.constructor == String
    return [a]
  null

genShapeDefinition = (name, code) -> """
shape f_#{name} (vec2 origin) {
#{code}
  return result;
}
"""

genConvexHullDefinition = (name, code) -> """
convex_hull #{name}_convex_hull (vec2 origin, vec2 dir, float offset) { 
#{code}
  return result;
}
"""

export class Canvas
  constructor: () ->
    @shapeNum  = 0
    @lastID    = 1 # FIXME - use 0 as background
    @codeChunks = []

  getNewID: () ->
    id = @lastID
    @lastID += 1
    id

  addCodeChunk: (c) -> @codeChunks.push c

  code: () ->
    @codeChunks.join '\n'

  newShape: () ->
    shape = @newShapeAlias()
    id    = @getNewID()
    shape.id = id
    shape

  newShapeAlias: () ->
    @shapeNum += 1
    canvasShape "shape_#{@shapeNum}"

  defNewShape: (fn, args...) ->
    gargs   = (toShapeCode arg for arg in args)
    sdfArgs = ['origin'].concat(gargs)
    sdfArgs = sdfArgs.join ','
    sdf     = "#{fn}(#{sdfArgs})"
    code    = getCodeCfg null

    gargs.unshift 'offset'
    gargs.unshift 'dir'
    gargs = gargs.join ','
    code.convexHull.push "dir = dir - origin;"
    code.convexHull.push "convex_hull result = #{fn}_convex_hull(#{gargs});"
    code.convexHull.push "result.distance -= dot(dir, origin);"

    @defShape "new", [sdf], {code, skipConvexHullRunner: true}


  defShape: (fn, args, cfg={}) ->
    code           = getCodeCfg cfg.code
    postCode       = getCodeCfg cfg.postCode
    shapeArgs      = toShapeArgs      args
    convexHullArgs = toConvexHullArgs args
    shape          = if cfg.keepID then @newShapeAlias() else @newShape()

    if cfg.transform?
      code.shape.push      "origin = #{cfg.transform 'origin'};"
      code.convexHull.push "origin = #{cfg.transform 'origin'};"
      code.convexHull.push "dir    = #{cfg.transform 'dir'};"

    if not cfg.skipShapeRunner
      code.shape.push "shape result = #{fn}(#{shapeArgs});"
    
    if not cfg.skipConvexHullRunner
      code.convexHull.push "convex_hull result = #{fn}(#{convexHullArgs});" 

    code.shape      = code.shape.concat      postCode.shape
    code.convexHull = code.convexHull.concat postCode.convexHull

    @addShapeCode code, shape
    shape


  addShapeCode: (code, shape) ->
    if shape.id?
      code.shape.push "result = setID(result,#{shape.id});"

    shapeCode      = assembleCode code.shape
    convexHullCode = assembleCode code.convexHull

    @addCodeChunk ( genShapeDefinition      shape.name, shapeCode      )
    @addCodeChunk ( genConvexHullDefinition shape.name, convexHullCode )

  # halfplane: (angle = 0, fast = false) ->
  #   g_a  = GLSL.toCode angle
  #   g_0  = GLSL.toCode 0
  #   bb   = "bbox_new(#{g_0},#{g_0})"
  #   glsl = if fast then switch angle
  #             when 0 then "sdf_halfplaneFast(p)"
  #             else        "sdf_halfplaneFast(p, #{g_a})"
  #          else switch angle
  #             when 0 then "sdf_halfplane(p)"
  #             else        "sdf_halfplane(p, #{g_a})"
  #   @defShape_OLD glsl, bb
  

  # pie: (angle) ->
  #   g_a  = GLSL.toCode angle
  #   g_0  = GLSL.toCode 0
  #   bb   = "bbox_new(#{g_0},#{g_0})"
  #   glsl = "sdf_pie(p,#{g_a})"
  #   @defShape_OLD glsl, bb

  # rect: (w,h, rs...) ->
  #   g_w  = GLSL.toCode w
  #   g_h  = GLSL.toCode h
  #   bb   = "bbox_new(#{g_w}/2.0,#{g_h}/2.0)"
  #   glsl = switch rs.length
  #     when 0 then "sdf_rect(p,vec2(#{g_w}, #{g_h}));"
  #     when 1 then "sdf_rect(p,vec2(#{g_w}, #{g_h}), #{GLSL.toCode rs[0]});"
  #     when 2 then "sdf_rect(p,vec2(#{g_w}, #{g_h}), vec4(#{GLSL.toCode rs[0]},#{GLSL.toCode rs[1]},#{GLSL.toCode rs[1]},#{GLSL.toCode rs[1]}));"
  #     when 3 then "sdf_rect(p,vec2(#{g_w}, #{g_h}), vec4(#{GLSL.toCode rs[0]},#{GLSL.toCode rs[1]},#{GLSL.toCode rs[2]},#{GLSL.toCode rs[2]}));"
  #     else        "sdf_rect(p,vec2(#{g_w}, #{g_h}), vec4(#{GLSL.toCode rs[0]},#{GLSL.toCode rs[1]},#{GLSL.toCode rs[2]},#{GLSL.toCode rs[3]}));"
  #   @defShape_OLD glsl, bb

  # triangle: (w, h) ->
  #   g_w = GLSL.toCode w
  #   g_h = GLSL.toCode h
  #   bb   = "bbox_new(#{g_w}/2.0,#{g_h}/2.0)"
  #   glsl = "sdf_triangle(p,#{g_w},#{g_h})"
  #   @defShape_OLD glsl, bb

  # quadraticCurveTo: (cx,cy,x,y) ->
  #   g_cx = GLSL.toCode cx
  #   g_cy = GLSL.toCode cy
  #   g_x  = GLSL.toCode x
  #   g_y  = GLSL.toCode y
  #   bb   = "bbox_new(0.0, 0.0)" # FIXME: http://pomax.nihongoresources.com/pages/bezier/
  #   glsl = "sdf_quadraticCurve(p, vec2(#{g_cx},#{g_cy}), vec2(#{g_x},#{g_y}));"
  #   @defShape_OLD glsl, bb

  # union:         (s1,s2)   -> 
  #   @defShape_OLD "sdf_union(#{s1.distance},#{s2.distance})", 
  #                 "bbox_union(#{s1.bbox},#{s2.bbox})", 
  #                 "color_merge(#{s1.distance},#{s2.distance},#{s1.color},#{s2.color})"
  #                 , @mergeIDLayers(s1,s2), false
  # unionRound:    (r,s1,s2) -> @defShape_OLD "sdf_unionRound(#{s1.distance},#{s2.distance},#{GLSL.toCode r})"      , "bbox_union(#{s1.bbox},#{s2.bbox})"    , "color_merge(#{s1.distance},#{s2.distance},#{s1.color},#{s2.color})", @mergeIDLayers(s1,s2)
       
  # grow:          (s1,r)    -> @defShape_OLD "sdf_grow(#{GLSL.toCode r},#{s1.distance})" , "bbox_grow(#{GLSL.toCode r},#{s1.bbox})" , s1.color
  # outside:       (s1)      -> @defShape_OLD "sdf_removeInside(#{s1.distance})"          , s1.bbox                                  , s1.color
  # inside:        (s1)      -> @defShape_OLD "sdf_removeOutside(#{s1.distance})"         , s1.bbox                                  , s1.color, @keepIDLayer(s1)
  # blur:          (s1,r, p) -> @defShape_OLD "sdf_blur(#{s1.distance}, #{GLSL.toCode r}, #{GLSL.toCode p})" , "bbox_grow(#{GLSL.toCode r},#{s1.bbox})" , s1.color
  # move:          (x,y)     -> @addCodeLine "origin = sdf_translate(origin, vec2(#{GLSL.toCode x}, #{GLSL.toCode y}));"
  # moveTo:        (x,y)     -> @addCodeLine "origin = vec2(#{GLSL.toCode x}, #{GLSL.toCode y});"
  # moveTo:        (x,y)     -> @addCodeLine "origin = vec2(#{GLSL.toCode x}, #{GLSL.toCode y});"
  # rotate:        (a)       -> @addCodeLine "origin = sdf_rotate(origin, - #{GLSL.toCode a});"
  # repeat:        (x,y)     -> @addCodeLine "origin = sdf_repeat(origin, vec2(#{GLSL.toCode x}, #{GLSL.toCode y}));"
    

  # fillGLSL:     (s1,s)    ->
  #   # cc = "rgb2lch(" + s + ")"
  #   cc = "(" + s + ")"
  #   @defShape_OLD s1.distance, s1.bbox, cc, @keepIDLayer(s1)


  # glslShape: (code, bbox="vec4(0.0,0.0,0.0,0.0)") -> @defShape_OLD code, bbox



###################
### SDF Objects ###
###################


cammelToSnakeCase = (s) ->
  s.split(/(?=[A-Z])/).join('_').toLowerCase()

snakeToCammelCase = (s) ->
  s.replace /_\w/g, (m) => m[1].toUpperCase()

glslArgs = (args) -> (GLSL.toCode arg for arg in args).join(', ')




export class Shape
  constructor: (name, @args, @glslBinding=(->)) ->
    @name = cammelToSnakeCase name
    @code = null

  TypeClass.implement @, M.add, (args...) -> @add args...
  TypeClass.implement @, M.sub, (args...) -> @sub args...
  TypeClass.implement @, M.mul, (args...) -> @mul args...

  render: (r) ->
    @renderer = r
    parms     = @glslBinding(@args...) ? {}
    if parms.transform?
      name    = ''
      inpArgs = [@args[0]]
    else if parms.output?
      name    = ''
      inpArgs = [parms.output]
    else
      nameSfx = if parms.nameSuffix? then "_#{parms.nameSuffix}" else ''
      name    = parms.name ? @name
      name    = name + nameSfx
      inpArgs = parms.args ? @args
    isModifier = false
    args       = []
    parms.code = mergeCodes @code, parms.code
    for arg in inpArgs
      if arg.constructor == Shape
        isModifier = true
        args.push r.renderShape(arg)
      else
        args.push arg

    if isModifier
      cfg = Object.assign {keepID:true}, parms
      r.canvas.defShape name, args, cfg 
    else
      r.canvas.defNewShape name, args...




bindShape = (name, glslBinding) -> (args...) -> new Shape name, args, glslBinding

bindMethod = (name, fn) ->
  def = bindShape name, fn
  Shape.prototype[name] = (args...) -> def @, args...
  def




#############
### Prims ###
#############

export circle    = bindShape 'circle'
export plane     = bindShape 'plane'
export rectangle = bindShape 'rectangle'
export halfPlane = bindShape 'halfPlane', (dir=0) ->
  switch dir
    when 0             then {nameSuffix: 'top'}
    when Math.PI * 0.5 then {nameSuffix: 'right'}
    when Math.PI       then {nameSuffix: 'bottom'}
    when Math.PI * 1.5 then {nameSuffix: 'left'}
    else {}



################
### Booleans ###
################

export intersection = bindMethod 'intersection'
export difference   = bindMethod 'difference'
export union        = bindMethod 'overloaded_union'
Shape::union = (args...) -> union @, args...



########################
### SDF Modification ###
########################

export grow = bindMethod 'grow', (base, radius) ->
  code: convexHull: "offset += #{GLSL.toCode radius};"
Shape::shrink = (radius) -> @grow(-radius)



##################
### Transforms ###
##################

export move = bindMethod 'move', (base, args...) ->
  transform: (name) => "sdf_translate(#{name},vec2(#{glslArgs args}))"
Shape::moveX = (x) -> @move x,0
Shape::moveY = (y) -> @move 0,y

export rotate = bindMethod 'rotate', (base, angle) ->
  transform: (name) => "sdf_rotate(#{name}, -(#{GLSL.toCode angle}))"  

export align = bindMethod 'align', (base, args...) ->
  ref    = @renderer.renderShape base
  args   = glslArgs args
  output = base.move("_tx")
  output.code = 
    [ "vec2 _dir = normalize(alignDir(#{args}));"
    , "vec2 _tx  = -#{ref.name}_convex_hull(vec2(0.0), _dir, 0.0).distance * _dir;"
    ]
  {output}
Shape::alignT  = -> @align  0 ,  1
Shape::alignB  = -> @align  0 , -1
Shape::alignL  = -> @align -1 ,  0
Shape::alignR  = -> @align  1 ,  0
Shape::alignTL = -> @alignT().alignL()
Shape::alignTR = -> @alignT().alignR()
Shape::alignBL = -> @alignB().alignL()
Shape::alignBR = -> @alignB().alignR()




# export class Repeat extends Shape
#   constructor: (@a, @dir, @length) -> super(); @addChildren @a
#   render: (r) -> r.withNewTxCtx () =>
#     len = @dir.length()
#     if len > 0
#       norm = @dir.normalize()
#       x    = norm.x * @length
#       y    = norm.y * @length
#       r.canvas.repeat(x,y)
#     r.renderShape @a
# Shape :: repeat = protoBindCons Repeat
# export repeat = consAlias Repeat



###############
### Filters ###
###############

# export class Blur extends Shape
#   constructor: (@a, @radius, @power=2.0) -> super(); @addChildren @a
#   render: (r) ->
#     a = r.renderShape @a
#     r.canvas.blur a, @radius, @power
# Shape::blur = protoBindCons Blur
# export blur = consAlias Blur



#############
### Color ###
#############

export fill = bindMethod 'fill'
# , (base, color) ->
#   if color.a == undefined
#     color = color.copy()
#     color.a = 1
#   return
#     args: [base, color]

# export class Fill extends Shape
#   constructor: (@a, @color) -> super(); @addChildren @a
#   render: (r) ->
#     a = r.renderShape @a
#     c = @color
#     if c.a == undefined
#       c = c.copy()
#       c.a = 1
#     r.canvas.defShape 'fill', [a, c]
    
# Shape::fill = protoBindCons Fill
# Shape::fill = protoBindCons Fill
# export fill = consAlias Fill


# export class FillGLSL extends Shape
#   constructor: (@a, @color) -> super(); @addChildren @a
#   render: (r) ->
#     a = r.renderShape @a
#     r.canvas.fillGLSL a, @color
# Shape::fillGLSL = protoBindCons FillGLSL
# export fillGLSL = consAlias FillGLSL





##############
### Curves ###
##############

    # export class QuadraticCurve extends Shape
    #   constructor: (@control,@destination) -> super()
    #   render: (r) -> r.canvas.quadraticCurveTo(@control.x, @control.y, @destination.x, @destination.y)
    # export quadraticCurve = consAlias QuadraticCurve

    # export class Path extends Shape
    #   constructor: (@segments) -> super(); @addChildren @segments...
    #   render: (r) ->
    #     rsegments = []
    #     interiors = []
    #     offset    = point 0,0

    #     r.withNewTxCtx () =>
    #       for curve in @segments
    #         r.canvas.move offset.x, offset.y
    #         rs       = r.renderShape curve
    #         offset   = curve.destination
    #         interior = "#{rs.name}_pathInterior"
    #         r.canvas.addCodeLine "bool #{interior} = quadraticCurve_interiorCheck(p, vec2(#{curve.control.x},#{curve.control.y}), vec2(#{curve.destination.x},#{curve.destination.y}));"
    #         rsegments.push rs
    #         interiors.push interior

    #     path = fold (r.canvas.union.bind r.canvas), rsegments
    #     interiorCheckExpr = GLSL.callRec 'interiorChec_union', interiors
    #     interior = "#{path.name}_pathInterior"

    #     r.canvas.addCodeLine "bool #{interior} = #{interiorCheckExpr};"
    #     shape = r.canvas.defShape_OLD "(#{interior}) ? (-#{path.name}) : (#{path.name})", "bbox_new(0.0, 0.0)"
    #     shape
    # export path = consAlias Path




#foldl :: (a -> b -> a) -> a -> [b] -> a
fold  = (f, bs) => foldl f, bs[0], bs.slice(1)
foldl = (f, a, bs) =>
  if bs.length == 0 then a
  else foldl f, f(a,bs[0]), bs.slice(1)



# export class CodeCtx extends Shape
#   constructor: (@a, @post=()->"") -> super(); @addChildren @a
#   render: (r) ->
#     a = r.renderShape @a
#     r.canvas.defShape_OLD (@post a)

# export class GLSLShape extends Shape
#   constructor: (@code) -> super()
#   render: (r) ->
#     r.canvas.glslShape @code


### Smart Constructors ###

### Primitive shapes ###

### Booleans ###

### ... ###
# export grow          = consAlias Grow
# export codeCtx       = consAlias CodeCtx
# export glslShape     = consAlias GLSLShape




# alignL = (a) -> a.move (negate a.bbox.left)  , 0
# alignR = (a) -> a.move (negate a.bbox.right) , 0
# alignT = (a) -> a.move 0, a.bbox.top
# alignB = (a) -> a.move 0, a.bbox.bottom

# alignTL = (a) -> alignT (alignL  a)
# alignTR = (a) -> alignT (alignR a)
# alignBL = (a) -> alignB (alignL  a)
# alignBR = (a) -> alignB (alignR a)


### Extensions ###


# Shape::alignTL = (args...) -> alignTL @, args...
# Shape::inside  = (args...) -> inside @, args...
# Shape.getter 'inside', -> inside @
# Shape.getter 'alignedTL', -> alignTL @
# Shape.getter 'alignedTR', -> alignTR @
# Shape.getter 'alignedBL', -> alignBL @
# Shape.getter 'alignedBR', -> alignBR @
# Shape.getter 'alignedL' , -> alignL @
# Shape.getter 'alignedR' , -> alignR @
# Shape.getter 'alignedT' , -> alignT @
# Shape.getter 'alignedB' , -> alignB @


# Shape::sub = (args...) -> @.difference args...
# Shape::add = (args...) -> @.union args...
# Shape::mul = (args...) -> @.intersection args...

Shape::sub = (args...) -> @.difference args...
Shape::add = (args...) -> @.union args...
Shape::mul = (args...) -> @.intersection args...


export class GLSLRenderer
  constructor: (@defs=[]) ->
    @canvas    = new Canvas
    @done      = new Map
    @idmap     = new Map
    # @txCtx     = 0
    # @txCtxNext = @txCtx + 1

  # getNewTxCtx: () ->
  #   ctx         = @txCtxNext
  #   @txCtx      = ctx
  #   @txCtxNext += 1
  #   ctx

  # withNewTxCtx: (f) ->
  #   oldCtx = @txCtx
  #   newCtx = @getNewTxCtx()
  #   @canvas.addCodeLine "vec2 origin_#{newCtx} = origin;"
  #   out    = f(newCtx)
  #   @canvas.addCodeLine "origin = origin_#{newCtx};"
  #   @txCtx = oldCtx
  #   out

  renderShape: (shape, cfg={}) ->
    shapeCache = @done.get(shape)
    if shapeCache != undefined
        cShape = shapeCache[@txCtx]
        if cShape != undefined then return cShape
    else
      shapeCache = {}

    sdef = shape.render @, cfg
    shapeCache[@txCtx] = sdef
    if sdef.number? then @idmap.set sdef.number, shape
    @done.set(shape, shapeCache)

    return sdef

  renderShapes: (shapes...) ->
    @renderShape shape for shape in shapes

  render: (s) ->
    shape    = @renderShape(s)
    # defsCode = 'shape _main(vec2 p) {\n' + @canvas.code() + "\nreturn shape(#{shape.distance}, #{shape.density}, #{shape.id}, #{shape.bbox}, #{shape.color});\n}"
    defsCode = @canvas.code()
    # defsCode = defsCode + '\n\nfff\n' + 'shape _main(vec2 origin) {\n' + @canvas.code() + "\nreturn #{shape.name};\n}"
    defsCode = defsCode + '\n\n\n' + 'shape _main(vec2 origin) {\n' + "return f_#{shape.name}(origin);\n}"
    # new ShaderBuilder (new SDFShader {fragment: defsCode}), @idmap
    {fragment: defsCode}




class ShaderBuilder
  constructor: (@fragment, @idmap=null, @attributes=null, @uniforms=null) ->

  compute: () ->
    body      = []
    vertDecls = []
    fragDecls = []
    if @attributes? then for [name, v] from @attributes
      varyingDecl =  "varying   #{v.type}   #{name};"
      vertDecls.push "attribute #{v.type} v_#{name};"
      vertDecls.push varyingDecl
      fragDecls.push varyingDecl
      body.push "#{name} = v_#{name};"
    if @uniforms? then for [name, v] from @uniforms
      uniformDecl = "uniform #{v.type} #{name};"
      vertDecls.push uniformDecl
      fragDecls.push uniformDecl

    body      = body.join '\n'
    vertDecls = vertDecls.join '\n'
    fragDecls = fragDecls.join '\n'
    vertex    = [vertexHeader  , vertDecls, 'void main() {', vertexBody, body, '}'].join('\n')
    fragment  = [fragmentHeader, fragDecls, fragment_lib, @fragment.genFragmentCode()].join('\n')
    {vertex, fragment}



export class Shader
  toShader: () -> new ShaderBuilder @


# FIXME: handle vertex shader
export class RawShader extends Shader
  constructor: (cfg) ->
    super()
    @vertex   = cfg.vertex
    @fragment = cfg.fragment

  genFragmentCode: () -> @fragment



# FIXME: handle vertex shader
export class SDFShader extends Shader
  constructor: (cfg) ->
    super()
    @vertex   = cfg.vertex
    @fragment = cfg.fragment

  genFragmentCode: () ->
    def  = @fragment.replace (/^shape\s+main/m), 'shape _main'
    code = [def, fragmentRunner].join '\n'
    code


# Shape::toShader = () -> (new GLSLRenderer).render @
Shape::toShader = () -> (new GLSLRenderer).render @
