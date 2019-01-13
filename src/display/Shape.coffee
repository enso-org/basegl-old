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

toConvexCode = (a) -> 
  if a instanceof CanvasShape2
    return "#{a.name}_convex_hull(origin,dir,offset)"
  else
    return GLSL.toCode a


assembleCode = (a) ->
  if not a?
    return ''
  if a.constructor == Array
    return '\n    ' + a.join('\n    ') + '\n'
  else if a.constructor == String
    return a
  else
    return null

getCodeLines = (a) ->
  if not a? 
    return []
  if a.constructor == Array
    return a.slice()
  else if a.constructor == String
    return [a]
  else
    return null


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
    id = @getNewID()
    @shapeNum += 1
    canvasShape "shape_#{@shapeNum}", id

  newShapeAlias: () ->
    @shapeNum += 1
    canvasShape "shape_#{@shapeNum}"

  defNewShape: (fn, args...) ->
    gargsx    = (toShapeCode arg for arg in args)
    gargs = gargsx.slice()
    gargs.unshift 'origin'
    gargs    = gargs.join ','
    distance = "#{fn}(#{gargs})"
    @defShape 'new', [distance], {convex: fn, convexArgs: gargsx}
    
  defShape: (fn, args, cfg={}) ->
    args = args.slice()
    args3 = args.slice()
    
    if fn == ""
      fnx = ""
    else
      fnx  = 'sdf_shape_' + fn

    if fn == ""
      fny = ""
    else
      fny  = 'convex_hull_' + fn
    if cfg.keepID
      shape = @newShapeAlias() 
    else 
      shape = @newShape()
      args.unshift "#{shape.id}"

    gargs = (toShapeCode arg for arg in args)
    gargs = gargs.join ','

    gargs3 = (toConvexCode arg for arg in args3)
    gargs3 = gargs3.join ','


    shapeCode      = []
    convexHullCode = []

    code = cfg.code
    if code?
      if code.constructor == Object
        shapeCode      = getCodeLines code.shape
        convexHullCode = getCodeLines code.convexHull
      else
        shapeCode      = getCodeLines code
        convexHullCode = getCodeLines code 

    if cfg.transform?
      shapeCode.push      "origin = #{cfg.transform 'origin'};"
      convexHullCode.push "origin = #{cfg.transform 'origin'};"
      convexHullCode.push "dir    = #{cfg.transform 'dir'};"

    shapeCode      = assembleCode shapeCode
    convexHullCode = assembleCode convexHullCode


    @addCodeChunk "sdf_symbol f_#{shape.name} (vec2 origin) {\n    #{shapeCode}return #{fnx}(#{gargs});\n}\n"

    if cfg.convex?
      gargs2 = cfg.convexArgs.slice()
      gargs2.unshift 'offset'
      gargs2.unshift 'dir'
      gargs2 = gargs2.join ','
      @addCodeChunk """
float #{shape.name}_convex_hull (vec2 origin, vec2 dir, float offset) 
{ #{convexHullCode}
  dir = dir - origin;
  float result = #{cfg.convex}_convex_hull(#{gargs2});
  result -= dot(dir, origin);
  return result;
}
"""
    else 
      @addCodeChunk """
float #{shape.name}_convex_hull (vec2 origin, vec2 dir, float offset)
{ #{convexHullCode}
  float result = #{fny}(#{gargs3});
  return result;
}
"""
    shape
    


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


# FIXME: Use M.<func> instad of basegl_sdfResolve. If resolve have to still be used, use typeclasses instead
# FIXME: Make basegl_sdfResolve like standard - check if everything implements it
# FIXME: Allow bboxes to be accessed as js struct / glsl code like everything else now
Number::basegl_sdfResolve = () -> @
String::basegl_sdfResolve = () -> @


resolve = (r,a) -> a.basegl_sdfResolve(r)

export negate = (a) -> a.basegl_sdfNegate()
Number::basegl_sdfNegate = () -> -@
String::basegl_sdfNegate = () -> '-' + @


export class BBox
  constructor: (@left, @top, @right, @bottom) ->

  basegl_sdfResolve: (r) -> new BBox (resolve r,@left), (resolve r,@top), (resolve r,@right), (resolve r,@bottom)


export class GLSLObjectRef
  constructor: (@shape, @selector) ->
    @_post = (a) => a

  copy: () -> new GLSLObjectRef @shape, @selector

  basegl_sdfNegate: () ->
    ref = @.copy()
    ref._post = (a) => (@_post a).basegl_sdfNegate()
    ref

  basegl_sdfResolve: (r) -> @_post (@selector (r.renderShape @shape))


glslBBRef = (shape, idx) -> new GLSLObjectRef shape, ((s) => s.bbox + '[' + idx + ']')

protoBind     = (f) -> (args...) -> f @, args...
protoBindCons = (t) -> protoBind (consAlias t)


cammelToSnakeCase = (s) ->
  s.split(/(?=[A-Z])/).join('_').toLowerCase()

snakeToCammelCase = (s) ->
  s.replace /_\w/g, (m) => m[1].toUpperCase()



export class Shape extends Composable
  cons: () ->
    @mixin styleMixin
    @mixin eventDispatcherMixin, @
    @type  = Shape

  TypeClass.implement @, M.add, (args...) -> @add args...
  TypeClass.implement @, M.sub, (args...) -> @sub args...
  TypeClass.implement @, M.mul, (args...) -> @mul args...

  render: (r) ->
    parms   = @glslBinding() ? {}
    nameSfx = if parms.nameSuffix? then "_#{parms.nameSuffix}" else ''
    name    = cammelToSnakeCase(@constructor.name) + nameSfx
    args    = parms.args ? []
    r.canvas.defNewShape name, args...

  glslBinding: ->


#############
### Prims ###
#############

export circle = consAlias class Circle extends Shape
  constructor: (@radius, @angle=null) -> super()
  glslBinding: -> 
    bbox: {x:@radius, y:@radius}
    args: if @angle == null then [@radius] else [@radius,@angle]

export plane = consAlias class Plane extends Shape

export halfPlane = consAlias class HalfPlane extends Shape
  constructor: (@dir = 0, @fast = false) -> super()
  glslBinding: -> 
    # TODO: Allow `dir` to be vector
    switch @dir 
      when 0             then {nameSuffix: 'top'}
      when Math.PI * 0.5 then {nameSuffix: 'right'}
      when Math.PI       then {nameSuffix: 'bottom'}
      when Math.PI * 1.5 then {nameSuffix: 'left'}
      else
        args: [@dir]
        nameSuffix: if @fast then 'fast' else null
        
# export class Pie extends Shape
#   constructor: (@angle) -> super()
#   render: (r) -> r.canvas.pie @angle
# export pie = consAlias Pie

export rectangle = consAlias class Rectangle extends Shape
  constructor: (@args...) -> super()
  glslBinding: ->
    args: @args

export triangle = consAlias class Triangle extends Shape
  constructor: (@args...) -> super()
  glslBinding: ->
    args: @args

export ellipse = consAlias class Ellipse extends Shape
  constructor: (@args...) -> super()
  glslBinding: ->
    args: @args

export ring = consAlias class Ring extends Shape
  constructor: (@args...) -> super()
  glslBinding: ->
    args: @args

# export class Triangle extends Shape
#   constructor: (@width, @height) -> super()
#   render: (r) -> r.canvas.triangle @width, @height
# export triangle = consAlias Triangle


s = fragment_lib

input = fragment_lib
targets = new Set
pfx     = 'sdf_'
pfxLen  = pfx.length
funcDef = /[a-zA-Z_][a-zA-Z_0-9]* +([a-zA-Z_][a-zA-Z_0-9]*) *\(/gm
m = funcDef.exec input
while m
  s = m[1]
  if s.startsWith pfx
    targets.add snakeToCammelCase(s.substr(pfxLen))
  m = funcDef.exec input

console.log targets



##############
### Curves ###
##############

export class QuadraticCurve extends Shape
  constructor: (@control,@destination) -> super()
  render: (r) -> r.canvas.quadraticCurveTo(@control.x, @control.y, @destination.x, @destination.y)
export quadraticCurve = consAlias QuadraticCurve

export class Path extends Shape
  constructor: (@segments) -> super(); @addChildren @segments...
  render: (r) ->
    rsegments = []
    interiors = []
    offset    = point 0,0

    r.withNewTxCtx () =>
      for curve in @segments
        r.canvas.move offset.x, offset.y
        rs       = r.renderShape curve
        offset   = curve.destination
        interior = "#{rs.name}_pathInterior"
        r.canvas.addCodeLine "bool #{interior} = quadraticCurve_interiorCheck(p, vec2(#{curve.control.x},#{curve.control.y}), vec2(#{curve.destination.x},#{curve.destination.y}));"
        rsegments.push rs
        interiors.push interior

    path = fold (r.canvas.union.bind r.canvas), rsegments
    interiorCheckExpr = GLSL.callRec 'interiorChec_union', interiors
    interior = "#{path.name}_pathInterior"

    r.canvas.addCodeLine "bool #{interior} = #{interiorCheckExpr};"
    shape = r.canvas.defShape_OLD "(#{interior}) ? (-#{path.name}) : (#{path.name})", "bbox_new(0.0, 0.0)"
    shape
export path = consAlias Path




#foldl :: (a -> b -> a) -> a -> [b] -> a
fold  = (f, bs) => foldl f, bs[0], bs.slice(1)
foldl = (f, a, bs) =>
  if bs.length == 0 then a
  else foldl f, f(a,bs[0]), bs.slice(1)



################
### Booleans ###
################

export class Union extends Shape
  constructor: (@shapes...) -> super(); @addChildren @shapes...
  render: (r) ->
    rs = r.renderShapes @shapes...
    # fold (r.canvas.union.bind r.canvas), rs
    # FIXME: use all rs!
    r.canvas.defShape 'union', [rs[0], rs[1]], {keepID: true}
    
Shape::union = protoBindCons Union
export union = consAlias Union

export class Intersection extends Shape
  constructor: (@shapes...) -> super(); @addChildren @shapes...
  render: (r) ->
    rs = r.renderShapes @shapes...
    # FIXME: use all rs!
    r.canvas.defShape 'intersection', [rs[0], rs[1]], {keepID: true}
    # fold (r.canvas.intersection.bind r.canvas), rs
Shape::intersection = protoBindCons Intersection
export intersection = consAlias Intersection

export class UnionRound extends Shape
  constructor: (@radius, @shapes...) -> super(); @addChildren @shapes...
  render: (r) ->
    rs = r.renderShapes @shapes...
    fold ((a,b) => (r.canvas.unionRound.bind r.canvas) @radius,a,b), rs
export unionRound = consAlias UnionRound


export class Difference extends Shape
  constructor: (@a, @b) -> 
    super()
    @addChildren @a, @b
  render: (r) ->
    [a, b] = r.renderShapes @a, @b
    r.canvas.defShape 'difference', [a, b], {keepID: true}
    
Shape::difference = protoBindCons Difference
export difference = consAlias Difference



########################
### SDF Modification ###
########################

export class Grow extends Shape
  constructor: (@a, @radius) -> super(); @addChildren @a
  render: (r) ->
    a = r.renderShape @a
    code =
      convexHull: "offset += #{GLSL.toCode @radius};"
    r.canvas.defShape 'grow', [a, @radius], {keepID: true, code}
    
Shape::grow = protoBindCons Grow
Shape::shrink = (radius) -> @grow(-radius)
export grow = consAlias Grow

export class Inside extends Shape
  constructor: (@a) -> super(); @addChildren @a
  render: (r) ->
    a = r.renderShape @a
    r.canvas.inside a
Shape::inside = protoBindCons Inside
export inside = consAlias Inside


glslArgs = (args) -> (GLSL.toCode arg for arg in args).join(', ')

##################
### Transforms ###
##################

export class Move extends Shape
  constructor: (@a, @args...) -> 
    super()
    @addChildren @a
  render: (r, cfg) ->
    code      = cfg.code
    tx        = "vec2(#{glslArgs @args})"
    transform = (name) => "sdf_translate(#{name},#{tx})"
    a = r.renderShape @a
    r.canvas.defShape "", [a], {code, transform}
Shape::move  = protoBindCons Move
Shape::moveX = (x) -> @move x,0
Shape::moveY = (y) -> @move 0,y
export move = consAlias Move


export class Rotate extends Shape
  constructor: (@a, @angle) -> super(); @addChildren @a
  render: (r) ->
    transform = (name) => "sdf_rotate(#{name}, -(#{GLSL.toCode @angle}))"    
    a = r.renderShape @a
    r.canvas.defShape "", [a], {transform}    
Shape :: rotate = protoBindCons Rotate
export rotate = consAlias Rotate


export class Align extends Shape
  constructor: (@a, @args...) -> 
    super()
    @addChildren @a
  render: (r) ->
    ref  = r.renderShape @a
    args = glslArgs @args
    code = 
      [ "vec2 _dir = normalize(alignDir(#{args}));"
      , "vec2 _tx  = -#{ref.name}_convex_hull(vec2(0.0), _dir, 0.0) * _dir;"
      ]
    r.renderShape @a.move("_tx"), {code}
Shape::align   = protoBindCons Align
Shape::alignT  = -> @align  0 ,  1
Shape::alignB  = -> @align  0 , -1
Shape::alignL  = -> @align -1 ,  0
Shape::alignR  = -> @align  1 ,  0
Shape::alignTL = -> @alignT().alignL()
Shape::alignTR = -> @alignT().alignR()
Shape::alignBL = -> @alignB().alignL()
Shape::alignBR = -> @alignB().alignR()
export align = consAlias Align




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

export class Blur extends Shape
  constructor: (@a, @radius, @power=2.0) -> super(); @addChildren @a
  render: (r) ->
    a = r.renderShape @a
    r.canvas.blur a, @radius, @power
Shape::blur = protoBindCons Blur
export blur = consAlias Blur



#############
### Color ###
#############

export class Fill extends Shape
  constructor: (@a, @color) -> super(); @addChildren @a
  render: (r) ->
    a = r.renderShape @a
    c = @color
    if c.a == undefined
      c = c.copy()
      c.a = 1
    r.canvas.defShape 'fill', [a, c]
    
Shape::fill = protoBindCons Fill
export fill = consAlias Fill


export class FillGLSL extends Shape
  constructor: (@a, @color) -> super(); @addChildren @a
  render: (r) ->
    a = r.renderShape @a
    r.canvas.fillGLSL a, @color
Shape::fillGLSL = protoBindCons FillGLSL
export fillGLSL = consAlias FillGLSL







export class CodeCtx extends Shape
  constructor: (@a, @post=()->"") -> super(); @addChildren @a
  render: (r) ->
    a = r.renderShape @a
    r.canvas.defShape_OLD (@post a)

export class GLSLShape extends Shape
  constructor: (@code) -> super()
  render: (r) ->
    r.canvas.glslShape @code


### Smart Constructors ###

### Primitive shapes ###

### Booleans ###

### ... ###
# export grow          = consAlias Grow
export codeCtx       = consAlias CodeCtx
export glslShape     = consAlias GLSLShape




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
Shape::inside  = (args...) -> inside @, args...
Shape.getter 'inside', -> inside @
# Shape.getter 'alignedTL', -> alignTL @
# Shape.getter 'alignedTR', -> alignTR @
# Shape.getter 'alignedBL', -> alignBL @
# Shape.getter 'alignedBR', -> alignBR @
# Shape.getter 'alignedL' , -> alignL @
# Shape.getter 'alignedR' , -> alignR @
# Shape.getter 'alignedT' , -> alignT @
# Shape.getter 'alignedB' , -> alignB @


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
    # defsCode = 'sdf_symbol _main(vec2 p) {\n' + @canvas.code() + "\nreturn sdf_symbol(#{shape.distance}, #{shape.density}, #{shape.id}, #{shape.bbox}, #{shape.color});\n}"
    defsCode = @canvas.code()
    # defsCode = defsCode + '\n\nfff\n' + 'sdf_symbol _main(vec2 origin) {\n' + @canvas.code() + "\nreturn #{shape.name};\n}"
    defsCode = defsCode + '\n\n\n' + 'sdf_symbol _main(vec2 origin) {\n' + "return f_#{shape.name}(origin);\n}"
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
    def  = @fragment.replace (/^sdf_symbol\s+main/m), 'sdf_symbol _main'
    code = [def, fragmentRunner].join '\n'
    code


Shape::toShader = () -> (new GLSLRenderer).render @
