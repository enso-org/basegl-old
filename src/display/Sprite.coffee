import * as matrix2 from 'gl-matrix'
import * as utils   from 'basegl/render/webgl'

import {Composable, fieldMixin}            from "basegl/object/Property"
import {DisplayObject, displayObjectMixin} from 'basegl/display/DisplayObject'
import {mat4, vec4}                        from 'gl-matrix'
import {Vector}                            from "basegl/math/Vector"
import {logger}                            from 'basegl/debug/logger'
import * as basegl from 'basegl'
import {circle, glslShape, union, grow, negate, rect, quadraticCurve, path, plane}      from 'basegl/display/Shape'
import * as Color     from 'basegl/display/Color'
import * as Symbol from 'basegl/display/Symbol'




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
    @size    = new Vector [ds, ds, 0], => @onTransformed()
    @_id     = null
    @_buffer = null
    @configure cfg

    @_displayObject.onTransformed = => @onTransformed()

    @variables = 
      color: new Vector [0,0,0], => 
        @_buffer.setVariable @_id, 'color', @variables.color


  onTransformed: () => 
    if not @isDirty then @_buffer.markDirty @

    


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
      @_gl.bindBuffer(@_gl.ELEMENT_ARRAY_BUFFER, @__indexBuffer)  
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
          type      = variable.type(@_gl)
          @_gl.vertexAttribPointer(
            varLoc, variable.size, type, normalize, stride, offset)

      
    @_gl.bindBuffer(@_gl.ELEMENT_ARRAY_BUFFER, null)


  # Sprite buffer uses indexed geometry. This function is used to build indices
  # pointing to specific vertexes during rendering stage. The sprite quad is
  # indexed as follow:
  #
  #  1 +---+ 2
  #    |   | 
  #  0 +---+ 3
  #
  # In reality, it consist of 2 triangles: {0,1,3} and {1,2,3}. The following
  # function creates mapping between quad indices and vertex ids.
  _buildIndices: () =>
    arr = new Uint16Array (@_size * @_SPRITE_VTX_COUNT)
    for i in [0 ... @_size]
      offset        = i * @_SPRITE_VTX_COUNT
      idx           = i * @_SPRITE_IND_COUNT
      arr[offset]   = idx
      arr[offset+1] = idx + 1
      arr[offset+2] = idx + 3
      arr[offset+3] = idx + 1
      arr[offset+4] = idx + 2
      arr[offset+5] = idx + 3
    arr


  resize: (newSizeExp) =>
    @_sizeExp = newSizeExp
    @_size    = 1 << (@_sizeExp - 1)
    @_ixPool.resize @_size
    @log "Resizing to 2^" + @_sizeExp + ' elements'

    # Indexing geometry
    indices = @_buildIndices()
    withBuffer @_gl, @_gl.ELEMENT_ARRAY_BUFFER, @__indexBuffer, =>
      @_gl.bufferData(@_gl.ELEMENT_ARRAY_BUFFER, indices, @_gl.STATIC_DRAW)

    # Updating attribute buffers
    varSpace = @_variables.attribute   
    for varName of varSpace
      variable       = varSpace[varName]
      defaultPattern = variable.defaultPattern #FIXME: handle patterns of wring sizes
      patternLength  = variable.size * @_SPRITE_IND_COUNT
      bufferUsage    = variable.usage || BufferUsage.DYNAMIC_DRAW
      
      bufferJS = if not variable.defaultPattern?
            new Float32Array(patternLength * @_size)
          else patternFloat32Array @_sizeExp, defaultPattern
      
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
        offset = elemCount * @_SPRITE_VTX_COUNT
        @_gl.drawElements(@_gl.TRIANGLES, offset, @_gl.UNSIGNED_SHORT, 0)

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
    buffer = @_buffers[name]

    srcOffset  = id * @_VTX_ELEMS   
    components = val.components

    for vtxIx in [0 ... @_SPRITE_IND_COUNT]
      offset = srcOffset + vtxIx * 3
      for componentIx in [0 ... 3]
        buffer.js[offset + componentIx] = components[componentIx]

    dstByteOffset = @_INT_BYTES * srcOffset
    length        = @_VTX_ELEMS

    arrayBufferSubData @_gl, buffer.gl, dstByteOffset, buffer.js, 
                       srcOffset, length 
                       

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
      p = vec4.create(); p[3] = 1

      p[0] = 0 
      p[1] = 0 
      p[2] = 0
      vec4.transformMat4 p, p, sprite.xform
      buffer.js[srcOffset]     = p[0]
      buffer.js[srcOffset + 1] = p[1]
      buffer.js[srcOffset + 2] = p[2]
      
      p[0] = 0 
      p[1] = sprite.size.y
      p[2] = 0
      vec4.transformMat4 p, p, sprite.xform
      buffer.js[srcOffset + 3] = p[0]
      buffer.js[srcOffset + 4] = p[1]
      buffer.js[srcOffset + 5] = p[2]
      
      p[0] = sprite.size.x
      p[1] = sprite.size.y
      p[2] = 0
      vec4.transformMat4 p, p, sprite.xform
      buffer.js[srcOffset + 6] = p[0]
      buffer.js[srcOffset + 7] = p[1]
      buffer.js[srcOffset + 8] = p[2]
      
      p[0] = sprite.size.x
      p[1] = 0
      p[2] = 0
      vec4.transformMat4 p, p, sprite.xform
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
      

