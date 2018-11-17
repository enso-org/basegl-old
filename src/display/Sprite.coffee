import * as matrix2 from 'gl-matrix'
import * as utils   from 'basegl/render/webgl'

import {Composable, fieldMixin}            from "basegl/object/Property"
import * as Property           from "basegl/object/Property"
import {DisplayObject, displayObjectMixin} from 'basegl/display/DisplayObject'
import * as Matrix                       from 'gl-matrix'
import {Vector}                            from "basegl/math/Vector"
import {logger}                            from 'logger'
import * as basegl from 'basegl'
import {circle, glslShape, union, grow, negate, rect, quadraticCurve, path, plane}      from 'basegl/display/Shape'
import * as Color     from 'basegl/display/Color'
import * as Symbol from 'basegl/display/Symbol'

# import * as Benchmark from 'benchmark'

import _ from 'lodash';
import process from 'process';

benchmark = require('benchmark');
Benchmark = benchmark.runInContext({ _, process });
window.Benchmark = Benchmark;



### BENCHMARKS ###

# bench = ->
#   typedArrayRW = ->
#     arr = new Float32Array 1000
#     return
#       name: 'typedArrayRW'
#       fn: ->
#         for i in [1...1000]
#           arr[i] = arr[i-1]+1


#   bufferRW = ->
#     arr = new Float32Array 1000
#     arr = new Buffer arr
#     return
#       name: 'bufferRW'
#       fn: ->
#         for i in [1...1000]
#           arr.write i, (arr.read(i-1)+1)

#   suite = new Benchmark.Suite

#   suite
#     .add typedArrayRW()
#     .add bufferRW()
      
#     .on  'cycle', (event)  -> console.log(String(event.target))
#     .on  'complete',       -> console.log('Fastest is ' + this.filter('fastest').map('name'))
#     .run({ 'async': false })

# arr = new Float32Array 10
# for i in [1...10]
#   arr[i] = arr[i-1]+1
# console.log arr


# arr = new Float32Array 10
# arr = new Buffer arr
# for i in [1...10]
#   arr.write i, (arr.read(i-1)+1)
# console.log arr


# bench()




##############
### Buffer ###
##############

# Buffer is a wrapper over any array-like object and exposes element read /
# write functions that can be overriden instead of inflexible index-based
# interface.

export class Buffer

  ### Properties ###
  constructor: (@array) ->
  @getter 'buffer'   , -> @array.buffer
  @getter 'length'   , -> @array.length
  @getter 'rawArray' , -> @array

  ### Read / Write ###
  read:          (ix)      -> @array[ix]
  write:         (ix, v)   -> @array[ix] = v 
  readMultiple:  (ixs)     -> @array[ix] for ix from ixs
  writeMultiple: (ixs, vs) -> @array[ix] = vs[i] for ix,i in ixs
  

  ### Redirect ###
  set: (args...) -> @array.set args...
  


##################
### Observable ###
##################

# Observable is a wrapper over any buffer-like object allowing to subscribe to
# changes by monkey-patching its methods.

export class Observable

  ### Properties ###

  constructor: (@array) -> 
  @getter 'buffer'   , -> @array.buffer
  @getter 'length'   , -> @array.length
  @getter 'rawArray' , -> @array.rawArray


  ### Read / Write ###

  read: (ix) -> @array.read ix
  
  readMultiple: (ixs) -> @array.readMultiple ixs 
  
  write: (ix, v) -> 
    @array.write ix, v
    @onChanged ix
  
  writeMultiple: (ixs, vs) ->
    @array.writeMultiple ixs, vs 
    @onChangedMultiple ixs


  ### Events ###  

  onChanged: (ix) ->
  onChangedMultiple: (ixs) ->
    for ix in ixs
      @onChanged ix



############
### View ###
############

# View is a wrapper over any buffer-like object allowing to view the array with
# a defined elements shift.

class View

  ### Properties ###
  constructor: (@array, @offset=0, @length=0) ->
  @getter 'buffer', -> @array.buffer

  ### Read / Write ###
  read:          (x)     -> @array.read          (x + @offset)
  readMultiple:  (xs)    -> @array.readMultiple  (x + @offset for x from xs)
  write:         (x , v) -> @array.write         (x + @offset), v
  writeMultiple: (xs, v) -> @array.writeMultiple (x + @offset for x from xs), v





#######################
### WebGL constants ###
#######################

export usage = 
  static      : WebGLRenderingContext.STATIC_DRAW
  dynamic     : WebGLRenderingContext.DYNAMIC_DRAW
  stream      : WebGLRenderingContext.STREAM_DRAW
  staticRead  : WebGLRenderingContext.STATIC_READ
  dynamicRead : WebGLRenderingContext.DYNAMIC_READ
  streamRead  : WebGLRenderingContext.STREAM_READ
  staticCopy  : WebGLRenderingContext.STATIC_COPY
  dynamicCopy : WebGLRenderingContext.DYNAMIC_COPY
  streamCopy  : WebGLRenderingContext.STREAM_COPY

export itemType =
  float : WebGLRenderingContext.FLOAT




###############################################################################
### OBSOLETE OBSOLETE OBSOLETE OBSOLETE OBSOLETE OBSOLETE OBSOLETE OBSOLETE ###
###############################################################################

WebGL = 
  SIZE_OF_FLOAT: 4

BufferUsage = 
  STATIC_DRAW  : 'STATIC_DRAW'
  DYNAMIC_DRAW : 'DYNAMIC_DRAW'
  STREAM_DRAW  : 'STREAM_DRAW'
  STATIC_READ  : 'STATIC_READ'
  DYNAMIC_READ : 'DYNAMIC_READ'
  STREAM_READ  : 'STREAM_READ'
  STATIC_COPY  : 'STATIC_COPY'
  DYNAMIC_COPY : 'DYNAMIC_COPY'
  STREAM_COPY  : 'STREAM_COPY'

patternFloat32Array = (iterations, pattern) ->
  chunks = 1 << (iterations - 1)
  length = chunks * pattern.length
  arr = new Float32Array length
  for i in [0 .. pattern.length - 1]
    arr[i] = pattern[i]
  p = pattern.length
  for i in [1 .. iterations - 1]
    arr.copyWithin p, 0, p
    p <<= 1
  arr 

# xarr = patternFloat32Array 8, [1,2,3,4]
# console.log xarr

withVAO = (gl, vao, f) -> 
  gl.bindVertexArray(vao)
  out = f()
  gl.bindVertexArray(null)
  out


withBuffer = (gl, type, buffer, f) -> 
  gl.bindBuffer(type, buffer)
  out = f()
  gl.bindBuffer(type, null)
  out

withArrayBuffer = (gl, buffer, f) ->
  withBuffer gl, gl.ARRAY_BUFFER, buffer, f 
  
arrayBufferSubData = (gl, buffer, dstByteOffset, srcData, srcOffset, length) ->
  withArrayBuffer gl, buffer, =>
    gl.bufferSubData(gl.ARRAY_BUFFER, dstByteOffset, srcData, srcOffset, length)
      

withNewArrayBuffer = (gl, f) ->
  buffer = gl.createBuffer()
  withArrayBuffer gl, buffer, => f(buffer)
  

class Pool 
  constructor: (@size=0) -> 
    @free      = []
    @nextIndex = 0

  reserve: () ->
    n = @free.shift()
    if n != undefined      then return n
    if @nextIndex == @size then return undefined
    n = @nextIndex
    @nextIndex += 1
    n

  dirtySize: () -> @nextIndex

  free: (n) ->
    @free.push(n)

  resize: (newSize) -> 
    @size = newSize


applyDef = (cfg, defCfg) ->
  if not cfg? then return defCfg
  for key of defCfg
    if cfg[key] == undefined
      cfg[key] = defCfg[key]


export class Sprite extends Composable
  @DEFAULT_SIZE = 10
  cons: (cfg) -> 
    @mixin displayObjectMixin, [], cfg
    ds       = Sprite.DEFAULT_SIZE
    @_id     = null
    @_buffer = null
    @configure cfg

    @_displayObject.onTransformed = => @onTransformed()

    @variables = 
      color: new Vector [0,0,0], => 
        @_buffer.setVariable @_id, 'color', @variables.color


  onTransformed: () => 
    if not @isDirty then @_buffer.markDirty @







############
### Type ###
############

# Type is a base-class for attribute types.

### Abstraction ###

export class Type
  @size       : 16
  @bufferCons : (args...) -> new Buffer (new Float32Array args...)
  @item       : itemType.float

  constructor: (@array) ->

  @getter 'buffer'   , -> @array.buffer
  @getter 'rawArray' , -> @array.rawArray
  
  # Smart constructor performing conversions if needed.
  @from: (args) ->
    cfg   = if args then args else @size
    array = @bufferCons cfg
    new @ array

  # View another buffer as desired type without copying.
  @view: (base, offset=0) ->
    arr = new View base, offset, @size
    new @ arr

  read:          (ix)      -> @array.read          ix
  write:         (ix,v)    -> @array.write         ix, v
  readMultiple:  (ixs)     -> @array.readMultiple  ixs
  writeMultiple: (ixs, vs) -> @array.writeMultiple ixs, vs


Property.swizzleFieldsXYZW2 Type
Property.swizzleFieldsRGBA2 Type
Property.addIndexFields2    Type


### Basic types ###

export class Vec2 extends Type
  @size: 2

export class Vec3 extends Type
  @size: 3 

export class Vec4 extends Type
  @size: 4 

export class Mat2 extends Type
  @size: 4

  @from: (args) =>
    if args
      array = @bufferCons args
    else
      array = @bufferCons @size
      array[0] = 1
      array[3] = 1
    new @ array

export class Mat3 extends Type
  @size: 9

  @from: (args) =>
    if args
      array = @bufferCons args
    else
      array = @bufferCons @size
      array[0] = 1
      array[4] = 1
      array[8] = 1
    new @ array

export class Mat4 extends Type
  @size: 16

  @from: (args) =>
    if args
      array = @bufferCons args
    else
      array = @bufferCons @size
      array[0]  = 1
      array[5]  = 1
      array[10] = 1
      array[15] = 1
    new @ array


### Smart constructors ###

vec2 = (a) -> Vec2.from a
vec3 = (a) -> Vec3.from a
vec4 = (a) -> Vec4.from a
mat2 = (a) -> Mat2.from a
mat3 = (a) -> Mat3.from a
mat4 = (a) -> Mat4.from a

vec2.type = Vec2
vec3.type = Vec3
vec4.type = Vec4
mat2.type = Mat2
mat3.type = Mat3
mat4.type = Mat4








#################
### Attribute ###
#################


export class Attribute

  ### Properties ###

  constructor: (@_type, @_size, cfg) -> 
    @_default    = cfg.default
    @_usage      = cfg.usage || usage.dynamic
    @_data       = new Observable (@type.bufferCons (@size * @type.size))
    @_dirty      = false
    @_dirtyRange = 
      min: null
      max: null

    @_data.onChanged = @_onChanged

  @getter 'type'    , -> @_type
  @getter 'size'    , -> @_size
  @getter 'data'    , -> @_data
  @getter 'default' , -> @_default


  ### Construction ###

  @from = (a) ->
    if a.constructor == Object
      @_from a.data, a.type, a
    else
      @_from a 

  @_inferArrType = (arr) -> arr[0].constructor
  @_from = (a, expType, cfg={}) ->
    if a.constructor == Array
      type = expType || @_inferArrType a
      size = a.length
      attr = new Attribute type, size, cfg
      attr.set a
      attr
    else if ArrayBuffer.isView a
      type = expType || @_inferArrType a
      size = a.length / type.size
      attr = new Attribute type, size, cfg
      attr.set a
      attr
    else new Attribute a.type, 0, cfg
    
  @fromObject: (cfg) ->
    attrs = {}
    for name of cfg
      attrs[name] = Attribute.from cfg[name]
    attrs


  ### Indexing ###

  read: (ix) ->
    @type.view @data, ix*@type.size 

  # TODO: should we trigger events here?
  set: (data) ->
    if data.constructor == Array
      size = @type.size
      for i in [0 ... data.length]
        offset = i * size
        @data.array.set data[i].rawArray, offset


  ### Event handling ###

  _onChanged: (ix) =>
    if @_dirty
      if      ix > @_dirtyRange.max then @_dirtyRange.max = ix
      else if ix < @_dirtyRange.min then @_dirtyRange.min = ix
    else
      @_dirty = true
      @_dirtyRange.min = ix
      @_dirtyRange.max = ix
      @onDirty @_name
    

  ### Events ###

  onDirty: (name) ->
  


# a = Attribute.from [
#   (vec3 [-0.5,  0.5, 0]),
#   (vec3 [-0.5, -0.5, 0]),
#   (vec3 [ 0.5,  0.5, 0]),
#   (vec3 [ 0.5, -0.5, 0])]

# a.onDirty = (i) ->
#   console.log "DIRTY", i
# console.log '-----'
# console.log a
# t = a.read(3)
# console.log t
# console.log t.xyz
# t[0] = 7
# t[1] = 7
# console.log a
# console.log '-----'


class Pool 
  constructor: (@size=0) -> 
    @free      = []
    @nextIndex = 0

  reserve: () ->
    n = @free.shift()
    if n != undefined      then return n
    if @nextIndex == @size then return undefined
    n = @nextIndex
    @nextIndex += 1
    n

  dirtySize: () -> @nextIndex

  free: (n) ->
    @free.push(n)

  resize: (newSize) -> 
    @size = newSize



class Pool2
  constructor: (required=0) -> 
    @size      = @_computeSquareSize required
    @free      = []
    @nextIndex = required

  _computeSquareSize: (required) ->
    if required == 0 
      size = 0
    else 
      size = 1
      while true
        if size < required
          size <<= 1
        else break
    size

  reserve: () ->
    n = @free.shift()
    if n != undefined      then return n
    if @nextIndex == @size then @grow()
    n = @nextIndex
    @nextIndex += 1
    n

  dirtySize: () -> @nextIndex

  free: (n) ->
    @free.push(n)

  resize: (newSize) -> 
    @size = newSize

  growTo: (required) -> 
    size = @_computeSquareSize required
    if size > @size 
      @size = size
      @onResized @size

  grow: () ->
    @size <<= 1
    @onResized @size

  reserveFromBeginning: (required) ->
    @growTo required
    @nextIndex = required

  ### Events ###
  onResized: (size) ->
    





#######################
### Attribute Scope ###
#######################



export class Scope

  ### Initialization ###

  constructor: (@geometry, @id, cfg) ->
    @logger      = @geometry.logger.scoped @id
    @attrs       = Attribute.fromObject cfg 
    @_dirtyAttrs = []

    for name,attr of @attrs 
      do (name,attr) =>
        attr.onDirty = =>
          console.log "DIRTY!!!", name
          @_dirtyAttrs.push name
        
    @_initIndexPool()

  _initIndexPool: () =>
    commonSize = @_computeCommonSize @attrs
    console.log "###", commonSize
    @pool      = new Pool2 commonSize
    @logger.info "Initializing for #{@pool.size} elements"

    @pool.onResized = @_onResized

  _computeCommonSize: (attrs) =>
    commonSize = 0
    for name of attrs
      attr = attrs[name]
      size = attr.size
      if size > commonSize
        commonSize = size
    commonSize

  add: (cfg) =>
    id = @pool.reserve()
    for name of cfg
      console.log "+", id, name
      console.log @attrs[name].attr

  addAttribute: (name, cfg) =>
    console.log "!!!", name, cfg
    attr = Attribute.from cfg
    console.log attr
    @pool.reserveFromBeginning attr.data.length
    # @geometry._onAttributeAdded @id, name
    

  ### Events ###

  _onResized: (s) =>
    console.log "TODO: resize buffers"
    @geometry._onScopeResized(@id, s)
        


# Geometry
#   - js buffers
#   - size management 

# GeometryBuffers
#   - per scene
#   - geo -> GL buffers
  


################
### Geometry ###
################

export class Geometry 
  constructor: (cfg) ->
    @name     = cfg.name || "Unnamed"
    @logger   = logger.scoped "Geometry.#{@name}"

    @_models  = []

    @logger.group 'Initialization', =>

      @_scope = 
        point    : new Scope @, 'point'    , cfg.point
        instance : new Scope @, 'instance' , cfg.instance
        # global   : new Scope cfg.global
      
      @point    = @_scope.point
      @instance = @_scope.instance

  _onScopeResized: (scope, size) -> 
    console.log "_onScopeResized", scope, size

  _onAttributeAdded: (scope, attr) ->
    console.log "_onAttributeAdded", scope, attr


export class GeometryModel
  constructor: () ->


export class Mesh
  constructor: (@geometry, @material) ->


export class MeshInstance
  constructor: (@_ctx, @mesh, @_program) ->
    @logger = logger
    @buffer = 
      point: {}
    @initVAO()
            
  initVAO: () => 
    @logger.group 'VAO initialization', =>
      @_vao = @_ctx.createVertexArray()
      @_initAttrs 'point', false

  _initAttrs: (spaceName, instanced) => 
    @logger.group "Initializing  #{spaceName} attributes", =>
      

      space = @mesh.geometry.point

      # @resize(@_sizeExp)
      # varSpace = @_variables.attribute
      # locSpace = @_locs.attribute
      withVAO @_ctx, @_vao, =>  
        for name of space
          @logger.info "Enabling attribute '#{name}'"
          attr = space[name]
          loc  = @_program.getAttribLocation name
          if loc == -1
            @logger.info "Attribute '" + name + "' not used in shader"
          else withNewArrayBuffer @_ctx, (buffer) =>  
            @buffer.point[name] = buffer 
            @_ctx.enableVertexAttribArray loc
            normalize = false
            stride    = 0
            offset    = 0
            type      = attr.attr.type.item
            size      = attr.attr.type.size
            @_ctx.vertexAttribPointer(loc, size, type, normalize, stride, offset)
            # if attr.instanced
            #   @_ctx.vertexAttribDivisor(loc, 1)


export test = (ctx) ->

  # buff = ctx.createBuffer()

  # steps = 20
  # max   = 100000000
  # step  = max / steps

  # withBuffer ctx, ctx.ARRAY_BUFFER, buff, =>
  #   for i in [step .. max] by step
  #     arr = new Float32Array i
  #     t1 = performance.now()
  #     ctx.bufferData(ctx.ARRAY_BUFFER, arr, ctx.STATIC_DRAW)
  #     t2 = performance.now()
  #     console.log (t2-t1)

  # arr = new Float32Array max
  # withBuffer ctx, ctx.ARRAY_BUFFER, buff, =>
  #   ctx.bufferData(ctx.ARRAY_BUFFER, arr, ctx.STATIC_DRAW)
  
  # steps = 20
  # max   = 1000000
  # step  = max / steps
  # withBuffer ctx, ctx.ARRAY_BUFFER, buff, =>
  #   for i in [step .. max] by step
  #     t1 = performance.now()
  #     for j in [0 ... i]
  #       ctx.bufferSubData(ctx.ARRAY_BUFFER, j, arr, j, 1)
  #     t2 = performance.now()
  #     console.log (t2-t1)

  # steps = 20
  # max   = 100000000
  # step  = max / steps
  # withBuffer ctx, ctx.ARRAY_BUFFER, buff, =>
  #   for i in [step .. max] by step
  #     t1 = performance.now()
  #     ctx.bufferSubData(ctx.ARRAY_BUFFER, 0, arr, 0, i)
  #     t2 = performance.now()
  #     console.log (t2-t1)


  # for i in [0 .. 0]
  #   withBuffer ctx, ctx.ARRAY_BUFFER, buff, =>
  #       ctx.bufferData(ctx.ARRAY_BUFFER, arr, ctx.STATIC_DRAW)
  # t2 = performance.now()
  # console.log "bufferData", (t2-t1)

  # t1 = performance.now()
  # withBuffer ctx, ctx.ARRAY_BUFFER, buff, =>
  #   for i in [0 .. 1000]
  #     ctx.bufferSubData(ctx.ARRAY_BUFFER, 0, arr, 0, 1)
  # t2 = performance.now()
  # console.log "bufferSubData", (t2-t1)

  program = utils.createProgramFromSources(ctx,
      [vertexShaderSource, fragmentShaderSource])

  geo = new Geometry
    name: "Geo1"
    point:
      position: 
        usage : usage.static
        data  : [
          (vec3 [-0.5,  0.5, 0]),
          (vec3 [-0.5, -0.5, 0]),
          (vec3 [ 0.5,  0.5, 0]),
          (vec3 [ 0.5, -0.5, 0])]
      uv:[
        # usage : usage.static
        # data  : [
          (vec2 [0,1]),
          (vec2 [0,0]),
          (vec2 [1,1]),
          (vec2 [1,0])] 
      
    instance:
      color:     vec3
      transform: mat4

  # console.log geo.point.attrs
  geo.point.attrs.position.read(0)[0] = 7
  geo.point.attrs.position.read(0)[0] = 7
  geo.point.attrs.position.read(0)[1] = 7

  # geo = new Geometry
  #   name: "Geo1"
  #   point: [
  #     { position: (vec3 -0.5,  0.5, 0), uv: (vec2 0, 1) } ,
  #     { position: (vec3 -0.5, -0.5, 0), uv: (vec2 0, 0) } ,
  #     { position: (vec3  0.5,  0.5, 0), uv: (vec2 1, 1) } ,
  #     { position: (vec3  0.5, -0.5, 0), uv: (vec2 1, 0) } ]
      
  #   instance:
  #     color:     vec3
  #     transform: mat4

  geo.point.addAttribute 'foo', [
          (vec2 [0,1]),
          (vec2 [0,0]),
          (vec2 [1,1]),
          (vec2 [1,1]),
          (vec2 [1,0])] 
  # geo.point.add 
  #   position : vec3 [1,1,1]
  #   uv       : vec2 [0,0]

  # mesh = new Mesh geo
  # mi = new MeshInstance ctx, mesh, program




export class SpriteBuffer
  constructor: (@name, @_gl, @_program, @_variables) ->
    @_SPRITE_IND_COUNT = 4
    @_SPRITE_VTX_COUNT = 6
    @_INT_BYTES        = 4
    @_VTX_DIM          = 3
    @_VTX_ELEMS        = @_SPRITE_IND_COUNT * @_VTX_DIM
    @_sizeExp          = 1

    @_ixPool           = new Pool
    @_vao              = @_gl.createVertexArray()
    @_locs             = @_program.lookupVariables @_variables  
    @__dirty           = []
    @_buffers          = {}

    @initVAO()
            
  initVAO: () => @logGroup 'VAO initialization', =>
    @__indexBuffer = @_gl.createBuffer()

    @resize(@_sizeExp)
    varSpace = @_variables.attribute
    locSpace = @_locs.attribute
    withVAO @_gl, @_vao, =>  
      for varName of varSpace
        @log "Enabling attribute '" + varName + "'"
        variable = varSpace[varName]
        varLoc   = locSpace[varName]      
        buffer   = @_buffers[varName]
        if varLoc == -1
          @log "Attribute '" + varName + "' not used in shader"
        else withArrayBuffer @_gl, buffer.gl, =>   
          @_gl.enableVertexAttribArray varLoc
          normalize = false
          stride    = 0
          offset    = 0
          type      = variable.value.webGLRepr.type.glType(@_gl)
          @_gl.vertexAttribPointer(
            varLoc, variable.value.webGLRepr.size, type, normalize, stride, offset)
          if variable.instanced
            @_gl.vertexAttribDivisor(varLoc, 1)



  resize: (newSizeExp) =>
    @_sizeExp = newSizeExp
    @_size    = 1 << (@_sizeExp - 1)
    @_ixPool.resize @_size
    @log "Resizing to 2^" + @_sizeExp + ' elements'

    # # Indexing geometry
    # indices = @_buildIndices()
    # withBuffer @_gl, @_gl.ELEMENT_ARRAY_BUFFER, @__indexBuffer, =>
    #   @_gl.bufferData(@_gl.ELEMENT_ARRAY_BUFFER, indices, @_gl.STATIC_DRAW)

    # Updating attribute buffers
    varSpace = @_variables.attribute   
    for varName of varSpace
      variable       = varSpace[varName]
      # defaultPattern = variable.defaultPattern #FIXME: handle patterns of wring sizes
      # patternLength  = variable.value.webGLRepr.size * @_SPRITE_IND_COUNT
      bufferUsage    = variable.usage || BufferUsage.DYNAMIC_DRAW
      
      bufferJS = null
      if variable.instanced
        bufferJS = new Float32Array(variable.value.webGLRepr.size * @_size)
        if variable.value?
          bufferJS.fill variable.value
      else
        bufferJS = new Float32Array(variable.value.webGLRepr.size * @_SPRITE_IND_COUNT)
        bufferJS.set variable.initData

      # bufferJS = if not variable.defaultPattern?
      #       new Float32Array(patternLength * @_size)
      #     else patternFloat32Array @_sizeExp, defaultPattern
      
      buffer = @_buffers[varName]
      if not buffer?
        buffer =
          js: bufferJS
          gl: @_gl.createBuffer()
      else
        bufferJS.set buffer.js
        buffer.js = bufferJS
      @_buffers[varName] = buffer

      withArrayBuffer @_gl, buffer.gl, =>
        @_gl.bufferData(@_gl.ARRAY_BUFFER, buffer.js, @_gl[bufferUsage])

  markDirty: (sprite) ->
    @__dirty.push(sprite)

  draw: (viewProjectionMatrix) ->
    @update() 
    withVAO @_gl, @_vao, =>
      @_gl.uniformMatrix4fv(@_locs.uniform.matrix, false, viewProjectionMatrix)
      elemCount = @_ixPool.dirtySize()
      if elemCount > 0
        # offset = elemCount * @_SPRITE_VTX_COUNT
        # @_gl.drawElements(@_gl.TRIANGLES, offset, @_gl.UNSIGNED_SHORT, 0)
        @_gl.drawArraysInstanced(@_gl.TRIANGLE_STRIP, 0, @_SPRITE_IND_COUNT, 1)

  create: => @logGroup "Creating sprite", =>
    ix = @_ixPool.reserve()
    if not ix?
      @resize(@_sizeExp * 2)
      ix = @_ixPool.reserve()
    @log "New sprite", ix
    new Sprite
      buffer : @
      id     : ix

  log: (args...) ->
    logger.info ("[SpriteBuffer." + @name + "]"), args...
  
  logGroup: (s,f) ->
    logger.group ("[SpriteBuffer." + @name + "] " + s), f


  setVariable: (id, name, val) ->
    # console.log '!!!!!', name, id
    buffer = @_buffers[name]
    components = val.components
    offset = id * 3
    for componentIx in [0 ... 3]
      buffer.js[offset + componentIx] = components[componentIx]
      # console.log "set", (offset + componentIx)

    dstByteOffset = @_INT_BYTES * offset
    length        = 3

    arrayBufferSubData @_gl, buffer.gl, dstByteOffset, buffer.js, 
                       offset, length 

  # setVariable: (id, name, val) ->
  #   console.log '!!!!!', name, id
  #   buffer = @_buffers[name]

  #   srcOffset  = id * @_VTX_ELEMS   
  #   components = val.components

  #   for vtxIx in [0 ... @_SPRITE_IND_COUNT]
  #     offset = srcOffset + vtxIx * 3
  #     for componentIx in [0 ... 3]
  #       buffer.js[offset + componentIx] = components[componentIx]

  #   dstByteOffset = @_INT_BYTES * srcOffset
  #   length        = @_VTX_ELEMS

  #   arrayBufferSubData @_gl, buffer.gl, dstByteOffset, buffer.js, 
  #                      srcOffset, length 
                       

  update: () ->
    # TODO: check on real use case if bulk update is faster
    USE_BULK_UPDATE = false

    dirtyRange = null

    if USE_BULK_UPDATE
      dirtyRange =
        min : undefined
        max : undefined

    buffer = @_buffers.position

    for sprite in @__dirty
      sprite.update()

      srcOffset = sprite.id * @_VTX_ELEMS   
      p = Matrix.vec4.create(); p[3] = 1
      ds = 0.5

      p[0] = -ds
      p[1] = ds 
      p[2] = 0
      Matrix.vec4.transformMat4 p, p, sprite.xform
      buffer.js[srcOffset]     = p[0]
      buffer.js[srcOffset + 1] = p[1]
      buffer.js[srcOffset + 2] = p[2]
      
      p[0] = -ds 
      p[1] = -ds
      p[2] = 0
      Matrix.vec4.transformMat4 p, p, sprite.xform
      buffer.js[srcOffset + 3] = p[0]
      buffer.js[srcOffset + 4] = p[1]
      buffer.js[srcOffset + 5] = p[2]
      
      p[0] = ds
      p[1] = ds
      p[2] = 0
      Matrix.vec4.transformMat4 p, p, sprite.xform
      buffer.js[srcOffset + 6] = p[0]
      buffer.js[srcOffset + 7] = p[1]
      buffer.js[srcOffset + 8] = p[2]
      
      p[0] = ds
      p[1] = -ds
      p[2] = 0
      Matrix.vec4.transformMat4 p, p, sprite.xform
      buffer.js[srcOffset + 9]  = p[0]
      buffer.js[srcOffset + 10] = p[1]
      buffer.js[srcOffset + 11] = p[2]
      
      if USE_BULK_UPDATE
        if not (sprite.id >= dirtyRange.min) then dirtyRange.min = sprite.id
        if not (sprite.id <= dirtyRange.max) then dirtyRange.max = sprite.id
      else
        dstByteOffset = @_INT_BYTES * srcOffset
        length        = @_VTX_ELEMS
        arrayBufferSubData @_gl, buffer.gl, dstByteOffset, buffer.js, 
                           srcOffset, length 

    if USE_BULK_UPDATE
      srcOffset     = dirtyRange.min * @_VTX_ELEMS
      dstByteOffset = @_INT_BYTES * srcOffset
      length        = @_VTX_ELEMS * (dirtyRange.max - dirtyRange.min + 1)
      arrayBufferSubData @_gl, buffer.gl, dstByteOffset, buffer.js, 
                         srcOffset, length 

    __dirty = []
      

