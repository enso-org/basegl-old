
import * as Property from "basegl/object/Property"
import * as Buffer   from 'basegl/data/buffer'
import * as Matrix   from 'gl-matrix'
import {singleShotEventDispatcher} from 'basegl/event/dispatcher'



##############
### GLType ###
##############

### Definition ###

class GLType
  constructor: (@id, cfg) ->
    @name      = cfg.name
    @code      = WebGLRenderingContext[@id]
    @uniSetter = cfg.uniSetter
    if cfg.item
      @item       = cfg.item
      @size       = cfg.size
      @byteSize   = @size * @item.byteSize
      @bufferType = @item.bufferType
    else
      @bufferType = cfg.bufferType    
      @item       = @
      @size       = 1
      @byteSize   = cfg.byteSize || @bufferType.BYTES_PER_ELEMENT

  newBuffer: (elems=1, cfg) ->
    new Buffer.Buffer @bufferType, (elems * @size), cfg

  newBufferfromArray: (array, cfg) ->
    new Buffer.Buffer @bufferType, array, cfg


### Batch preparation ###

typesCfg =
  float        : {name: 'float'     , uniSetter: ((gl, loc, val) -> gl.uniform1fv loc, val) , bufferType: Float32Array}
  int          : {name: 'int'       , uniSetter: ((gl, loc, val) -> gl.uniform1iv loc, val) , bufferType: Int32Array}
  float_vec2   : {name: 'vec2'      , uniSetter: ((gl, loc, val) -> gl.uniform2fv loc, val) , item: 'float' , size: 2}
  float_vec3   : {name: 'vec3'      , uniSetter: ((gl, loc, val) -> gl.uniform3fv loc, val) , item: 'float' , size: 3}
  float_vec4   : {name: 'vec4'      , uniSetter: ((gl, loc, val) -> gl.uniform4fv loc, val) , item: 'float' , size: 4}
  int_vec2     : {name: 'ivec2'     , uniSetter: ((gl, loc, val) -> gl.uniform2iv loc, val) , item: 'int'   , size: 2}
  int_vec3     : {name: 'ivec3'     , uniSetter: ((gl, loc, val) -> gl.uniform3iv loc, val) , item: 'int'   , size: 3}
  int_vec4     : {name: 'ivec4'     , uniSetter: ((gl, loc, val) -> gl.uniform4iv loc, val) , item: 'int'   , size: 4}
  float_mat2   : {name: 'mat2'      , uniSetter: ((gl, loc, val) -> gl.uniformMatrix2fv loc, false, val) , item: 'float' , size: 4}
  float_mat3   : {name: 'mat3'      , uniSetter: ((gl, loc, val) -> gl.uniformMatrix3fv loc, false, val) , item: 'float' , size: 9}
  float_mat4   : {name: 'mat4'      , uniSetter: ((gl, loc, val) -> gl.uniformMatrix4fv loc, false, val) , item: 'float' , size: 16}
  sampler2D    : {name: 'sampler2D' , uniSetter: ((gl, loc, val) -> gl.uniform1i  loc, val) , item: 'float' , size: null}

webGL = {types: {}}
for name,cfg of typesCfg
  if cfg.item?
    cfg.item = webGL.types[cfg.item]
  glName = name.toUpperCase()
  webGL.types[name] = new GLType glName, cfg

notImplementError = (cons, fn) -> 
  throw "Type #{cons} does not implement '#{fn}' method"

export class Type
  @default : -> notImplementError @name, 'default'
  
  toGLSL   : -> notImplementError @constructor.name, 'toGLSL'
  @getter 'rawArray', -> notImplementError @constructor.name, 'rawArray'



###############
### Texture ###
###############

class TextureWrapper
  @generateAccessors()

  @glType: webGL.types.sampler2D
  @getter 'type'   , -> Texture # FIXME: outside reference, we use it while rendering mesh
  @getter 'glType' , -> @constructor.glType

  constructor: (@_texture) ->
  glValue: -> @texture


class Texture
  @generateAccessors()

  @glType: webGL.types.sampler2D
  @getter 'type'   , -> @constructor
  @getter 'glType' , -> @constructor.glType
  
  constructor: (url) ->
    @_onLoaded = singleShotEventDispatcher() 
    @_cache    = new WeakMap
    if url?
      @_load url

  _load: (url) -> 
    @image = new Image()
    @image.crossOrigin = 'anonymous'
    @image.onload = =>
      @onLoaded.dispatch()
    @image.src = url
    
  glValue: (gl) ->
    texture = @cache.get gl
    if texture then return texture

    tmpImage       = new Uint8Array [0,0,0,0]
    tmpWidth       = 1
    tmpHeight      = 1
    tmpBorder      = 0
    level          = 0
    internalFormat = gl.RGBA
    format         = gl.RGBA
    type           = gl.UNSIGNED_BYTE
    
    texture = gl.createTexture()
    @cache.set gl, texture
    gl.bindTexture gl.TEXTURE_2D, texture
    gl.texImage2D  gl.TEXTURE_2D, level, internalFormat, tmpWidth, tmpHeight, 
                   tmpBorder, format, type, tmpImage
    gl.texParameteri gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE
    gl.texParameteri gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE
    gl.texParameteri gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR


    @onLoaded.addEventListener =>
      gl.bindTexture gl.TEXTURE_2D, texture
      gl.texImage2D gl.TEXTURE_2D, level, internalFormat, format, type, @image

      if isPowerOf2 @image.width && isPowerOf2 @image.height 
        gl.generateMipmap gl.TEXTURE_2D
      else
        gl.texParameteri gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE
        gl.texParameteri gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE
        gl.texParameteri gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR
    
    texture


isPowerOf2 = (value) ->
  (value & (value - 1)) == 0

# export texture = (args...) -> new Texture args...

export texture = (cfg) ->
  if (not cfg?) || (typeof cfg == 'string')
    new Texture cfg
  else 
    new TextureWrapper cfg
texture.type = Texture


##################
### BufferType ###
##################

# BufferType is a base-class for buffer-like attribute types.

### Abstraction ###

export class BufferType extends Type
  constructor: (@array) -> super()
  @getter 'type'     , -> @constructor
  @getter 'length'   , -> @glType.size
  @getter 'buffer'   , -> @array.buffer
  @getter 'rawArray' , -> @array.rawArray
  @getter 'glType'   , -> @constructor.glType
  
  @from: (args) ->
    len = args.length
    if len == 0
      @default() 
    else if len == @glType.size
      new @ (@glType.newBufferfromArray args)
    else
      buffer = @default()
      buffer.array.set args 
      buffer

  @bindableFrom: (args) ->
    buffer = @from args
    buffer.array = new Buffer.Bindable buffer.array
    buffer

  @getter 'onChanged', -> @array.onChanged
  @observableFrom: (args) ->
    buffer = @from args
    buffer.array = new Buffer.Observable buffer.array
    buffer

  @default: -> new @ @glType.newBuffer()

  # View another buffer as desired type without copying.
  @view: (base, offset=0) ->
    arr = new Buffer.View base, offset, @size
    new @ arr

  read:          (ix)      -> @array.read          ix
  write:         (ix,v)    -> @array.write         ix, v
  readMultiple:  (ixs)     -> @array.readMultiple  ixs
  writeMultiple: (ixs, vs) -> @array.writeMultiple ixs, vs
  glValue:                 -> @rawArray

  clone: ->
    new @ (@glType.newBufferfromArray @rawArray)

  set: (src) ->
    for i in [0 ... @glType.size]
      @write i, src.read(i)

  toGLSL: ->
    name = @glType.name
    args = @rawArray.join ','
    args = (toGLSL a for a in @rawArray)
    "#{name}(#{args.join(',')})"

    
Property.swizzleFieldsXYZW2 BufferType
Property.swizzleFieldsRGBA2 BufferType
Property.addIndexFields2    BufferType, 16


### Basic types ###

export class Float extends Type
  @glType  : webGL.types.float
  @default : -> new Float 0

  constructor: (@number=0) -> super()
  @getter 'type'    , -> @constructor  
  @getter 'glType'  , -> @constructor.glType
  @getter 'rawArray', -> new Float32Array [@number]

  glValue: -> @rawArray
  toGLSL: -> if @number % 1 == 0 then "#{@number}.0" else "#{@number}"

export class Vec2 extends BufferType
  @glType: webGL.types.float_vec2

export class Vec3 extends BufferType
  @glType: webGL.types.float_vec3

export class Vec4 extends BufferType
  @glType: webGL.types.float_vec4
  @default: ->
    array = super.default()
    array[3] = 1
    array

export class Mat2 extends BufferType
  @glType: webGL.types.float_mat2
  @default: ->
    array = super.default()
    array[0] = 1
    array[3] = 1
    array

export class Mat3 extends BufferType
  @glType: webGL.types.float_mat3
  @default: ->
    array = super.default()
    array[0] = 1
    array[4] = 1
    array[8] = 1
    array

export class Mat4 extends BufferType
  @glType: webGL.types.float_mat4
  @default: ->
    array = super.default()
    array[0]  = 1
    array[5]  = 1
    array[10] = 1
    array[15] = 1
    array

  perspective: (fovy, aspect, near, far) -> 
    Matrix.mat4.perspective @rawArray, fovy, aspect, near, far

  invert:              -> @invertFrom @rawArray
  inverted:            -> @clone().invert()
  invertFrom: (matrix) -> Matrix.mat4.invert @rawArray, matrix
  
  

### Smart constructors ###

export float = (args...) => new Float args...
export vec2 = (args...) => Vec2.from args
export vec3 = (args...) => Vec3.from args
export vec4 = (args...) => Vec4.from args
export mat2 = (args...) => Mat2.from args
export mat3 = (args...) => Mat3.from args
export mat4 = (args...) => Mat4.from args

float.type = Float
vec2.type = Vec2
vec3.type = Vec3
vec4.type = Vec4
mat2.type = Mat2
mat3.type = Mat3
mat4.type = Mat4




export value = (a) ->
  switch a.constructor
    when Number then new Float a
    else a

export type = (a) -> 
  switch a.constructor
    when Number   then Float
    else a.type

export toGLSL = (a) -> value(a).toGLSL()
