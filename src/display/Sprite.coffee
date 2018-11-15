import * as matrix2 from 'gl-matrix'
import * as utils   from 'basegl/render/webgl'

import {Composable, fieldMixin}            from "basegl/object/Property"
import {DisplayObject, displayObjectMixin} from 'basegl/display/DisplayObject'
import * as Matrix                       from 'gl-matrix'
import {Vector}                            from "basegl/math/Vector"
import {logger}                            from 'logger'
import * as basegl from 'basegl'
import {circle, glslShape, union, grow, negate, rect, quadraticCurve, path, plane}      from 'basegl/display/Shape'
import * as Color     from 'basegl/display/Color'
import * as Symbol from 'basegl/display/Symbol'



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

    

class Vec3
  constructor: (args) ->
    @_arr = new Float32Array (if args then args else 3)

class Vec2
  constructor: (args) ->
    @_arr = new Float32Array (if args then args else 2)

class Mat4
  constructor: (args) ->
    if args
      @_arr = new Float32Array args
    else
      @_arr = new Float32Array 16
      @_arr[0]  = 1
      @_arr[5]  = 1
      @_arr[10] = 1
      @_arr[15] = 1


vec3 = (args) -> new Vec3 args
vec3.size       = 3
vec3.bufferType = Float32Array
vec3.itemType   = itemType.float

vec2 = (args) -> new Vec2 args
vec2.size       = 2
vec2.bufferType = Float32Array
vec2.itemType   = itemType.float

mat4 = (args) -> new Mat4 args
mat4.size       = 16
mat4.bufferType = Float32Array
mat4.itemType   = itemType.float

Vec3.prototype.type = vec3
Vec2.prototype.type = vec2
Mat4.prototype.type = mat4







export class AttributeArray 
  constructor: (@_arr=[]) -> 

export class Attribute
  constructor: (cfg) -> 
    @_type    = cfg.type
    @_data    = cfg.data
    @_default = cfg.default
    @_usage   = cfg.usage || usage.dynamic

  @getter 'type'    , -> @_type
  @getter 'data'    , -> @_data
  @getter 'default' , -> @_default

  @from = (cfg) -> 
    inferArrType = (arr) -> arr[0].type
    switch cfg.constructor
      when Object then cfg2 =
        data  : cfg.data
        type  : cfg.type || inferArrType cfg.data
        usage : cfg.usage
      when Array  then cfg2 = 
        data: new AttributeArray cfg
        type: inferArrType cfg
      else cfg2 =
        data: new AttributeArray
        type: cfg
    new Attribute cfg2
    
  @fromObject: (cfg) ->
    attrs = {}
    for name of cfg
      attrs[name] = Attribute.from cfg[name]
    attrs


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
    @size      = @_computeInitSize required
    @free      = []
    @nextIndex = 0

  _computeInitSize: (required) ->
    if required == 0 
      size = 0
    else 
      size = 1
      while true
        if size >= required then break
        size <<= 1
    size

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



##############
### Buffer ###
##############

export class Buffer
  constructor: (@type, @size) ->
    @js = new @type @size

  moveTo: (newJS) ->
    newJS.set @js
    @js = newJS



#######################
### BufferAttribute ###
#######################

export class BufferAttribute
  constructor: (@attr, size) ->
    @buffer = new Buffer @attr.type.bufferType, size


export class BufferAttributeScope

  ### Initialization ###

  constructor: (parent, @name, cfg) ->
    @logger = parent.logger.scoped @name
    attrs   = Attribute.fromObject cfg       
    @_initIndexPool   attrs
    @_initBufferAttrs attrs

  _initIndexPool: (attrs) ->
    commonSize = @_computeCommonSize attrs
    @pool      = new Pool2 commonSize 
    @logger.info "Initializing for #{@pool.size} elements"

  _initBufferAttrs: (attrs) ->
    @attrs = {}
    for name of attrs
      @attrs[name] = new BufferAttribute attrs[name], @pool.size

  _computeCommonSize: (attrs) ->
    size = 0
    for name of attrs
      attr = attrs[name]
      len  = attr.data.length
      if len > size
        size = len
    size




################
### Geometry ###
################

export class Geometry 
  constructor: (cfg) ->
    @name     = cfg.name || "Unnamed"
    @logger   = logger.scoped "Geometry.#{@name}"

    @logger.group 'Initialization', =>

      @_scope = 
        point    : new BufferAttributeScope @, 'PointBuffer'    , cfg.point
        instance : new BufferAttributeScope @, 'InstanceBuffer' , cfg.instance
        # global   : new Scope cfg.global
      
      @point    = @_scope.point
      @instance = @_scope.instance



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
            type      = attr.attr.type.itemType
            size      = attr.attr.type.size
            @_ctx.vertexAttribPointer(loc, size, type, normalize, stride, offset)
            # if attr.instanced
            #   @_ctx.vertexAttribDivisor(loc, 1)


export test = (ctx) ->

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
      uv:
        usage : usage.static
        data  : [
          (vec2 [0,1]),
          (vec2 [0,0]),
          (vec2 [1,1]),
          (vec2 [1,0])] 
      
    instance:
      color:     vec3
      transform: mat4

  mesh = new Mesh geo
  mi = new MeshInstance ctx, mesh, program




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
    console.log '!!!!!', name, id
    buffer = @_buffers[name]
    components = val.components
    offset = id * 3
    for componentIx in [0 ... 3]
      buffer.js[offset + componentIx] = components[componentIx]
      console.log "set", (offset + componentIx)

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
      

