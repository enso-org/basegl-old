
import * as Property from "basegl/object/Property"
import * as Buffer   from 'basegl/data/buffer'
import * as Matrix   from 'gl-matrix'
import {singleShotEventDispatcher} from 'basegl/event/dispatcher'



GL = WebGLRenderingContext

###############
### Texture ###
###############

class TextureWrapper
  @generateAccessors()

  @gl:
    name: 'sampler2D'
    uniSetter: (gl, loc, val) -> gl.uniform1i  loc, val

  @getter 'type'   , -> Texture # FIXME: outside reference, we use it while rendering mesh
  @getter 'gl'     , -> @constructor.gl

  constructor: (@_texture) ->
  glValue: -> @texture


class Texture
  @generateAccessors()

  @gl:
    name: 'sampler2D'
    uniSetter: (gl, loc, val) -> gl.uniform1i  loc, val

  @getter 'type'   , -> @constructor
  @getter 'gl'     , -> @type.gl
  
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






getConstructorChain = (cls) ->
  chain = []
  while cls != Object
    chain.unshift cls
    cls = Object.getPrototypeOf(cls.prototype).constructor
  chain

smartConstructor = (cls, cfg={}) ->
  fnName = cfg.constructor || null
  if fnName == null
    fn = (args...) => new cls args...
  else 
    fn = cls[fnName].bind cls

  consChain = getConstructorChain cls
  for cons in consChain
    for key in Object.getOwnPropertyNames cons
      if not (key in ['length', 'name'])
        prop = cons[key]
        if typeof prop == 'function'
          fn[key] = prop.bind cls
        else
          fn[key] = prop
  
  fn



##############################
### Smart class generation ###
##############################

gl = (cls) ->
  if not cls.size?
    cls.size = 1
  if not cls.item?
    cls.item = cls
  if not cls.bufferType?
    if cls.item == cls
      throw "Cannot infer bufferType"
    cls.bufferType = cls.item.bufferType
  if not cls.byteSize?
    if cls.item == cls
      cls.byteSize = cls.bufferType.BYTES_PER_ELEMENT * cls.size
    else
      cls.byteSize = cls.item.byteSize * cls.size
  if not cls.gl.name?
    cls.gl.name = cls.name.toLowerCase()

  if not cls.gl.code?
    codeName = cls.name.toUpperCase()
    if cls.item != cls
      codeName = cls.item.name.toUpperCase() + '_' + codeName
    cls.gl.code = GL[codeName]

  proto = cls.prototype
  cls.getter 'type'       , -> @constructor
  cls.getter 'gl'         , -> @type.gl
  cls.getter 'item'       , -> @type.item
  cls.getter 'bufferType' , -> @type.bufferType
  cls.getter 'size'       , -> @type.size  
  cls.newBuffer = (elems=1, cfg) ->
    new Buffer.Buffer @bufferType, (elems * @size), cfg

  smartCons = smartConstructor cls,
    constructor: 'from'
  smartCons.type = cls
  smartCons



#####################
### Numeric types ###
#####################

class NumberBase
  @generateAccessors()
  constructor : (@_array) -> 
  @default: -> @from 0
  @from : (a) -> 
    if a.constructor == Number
      array = new @bufferType [a]
      new @ array
    else
      new @ a
  @getter 'value',     -> @array[0]
  @setter 'value', (v) -> @array[0] = v  
  glValue: -> @array

export float = gl class Float extends NumberBase
  @bufferType : Float32Array
  @gl: uniSetter: (gl, loc, val) -> gl.uniform1fv loc, val
  toGLSL: -> if @value % 1 == 0 then "#{@value}.0" else "#{@value}"

export int = gl class Int extends NumberBase
  @bufferType : Int32Array
  @gl: uniSetter: (gl, loc, val) -> gl.uniform1iv loc, val
  toGLSL: -> "#{@value}"

export uint = gl class UInt extends NumberBase
  @bufferType : Uint32Array
  @gl: uniSetter: (gl, loc, val) -> gl.uniform1uiv loc, val
  toGLSL: -> "#{@value}"



####################
### Vector types ###
####################

export class VecBase
  @generateAccessors()

  constructor: (@_buffer) ->
  @getter 'array', -> @buffer.array

  @from: (args...) ->
    len = args.length
    if len == 0
      @default() 
    else if len == @size
      @fromArray args
    else
      buffer = @default()
      buffer.buffer.set args 
      buffer

  @fromArray: (array, cfg) ->
    buffer = new Buffer.Buffer @bufferType, array, cfg
    new @ buffer

  @default: -> 
    new @ @newBuffer()

  @bindableFrom: (args) ->
    buffer = @from args...
    buffer._buffer = new Buffer.Bindable buffer.buffer
    buffer

  @getter 'onChanged',     -> @buffer.onChanged
  @setter 'onChanged', (v) -> @buffer.onChanged = v

  @observableFrom: (args) ->
    buffer = @from args...
    buffer._buffer = new Buffer.Observable buffer.buffer
    buffer

  # View another buffer as desired type without copying.
  @view: (base, offset=0) ->
    arr = new Buffer.View base, offset, @size
    new @ arr

  read:          (ix)      -> @buffer.read          ix
  write:         (ix,v)    -> @buffer.write         ix, v
  readMultiple:  (ixs)     -> @buffer.readMultiple  ixs
  writeMultiple: (ixs, vs) -> @buffer.writeMultiple ixs, vs
  glValue:                 -> @array

  clone: ->
    @type.fromArray @array

  set: (src) ->
    for i in [0 ... @size]
      @write i, src.read(i)

  toGLSL: ->
    name = @gl.name
    args = @array.join ','
    args = (toGLSL a for a in @array)
    "#{name}(#{args.join(',')})"

Property.swizzleFieldsXYZW2 VecBase
Property.swizzleFieldsRGBA2 VecBase
Property.addIndexFields2    VecBase, 16



export vec2 = gl class Vec2 extends VecBase
  @size: 2
  @item: float
  @gl: 
    textureFormat: GL.RG32F
    uniSetter: (gl, loc, val) -> gl.uniform2fv loc, val

export ivec2 = gl class IVec2 extends VecBase
  @size: 2
  @item: int
  @gl: 
    textureFormat: GL.RG32I
    uniSetter: (gl, loc, val) -> gl.uniform2iv loc, val

export uivec2 = gl class UIVec2 extends VecBase
  @size: 2
  @item: uint
  @gl: 
    textureFormat: GL.RG32UI
    uniSetter: (gl, loc, val) -> gl.uniform2uiv loc, val



export vec3 = gl class Vec3 extends VecBase
  @size: 3
  @item: float
  @gl:
    textureFormat: GL.RGB32F 
    uniSetter: (gl, loc, val) -> gl.uniform3fv loc, val

export ivec3 = gl class IVec3 extends VecBase
  @size: 3
  @item: int
  @gl: 
    textureFormat: GL.RGB32I 
    uniSetter: (gl, loc, val) -> gl.uniform3iv loc, val

export uivec3 = gl class UIVec3 extends VecBase
  @size: 3
  @item: uint
  @gl: 
    textureFormat: GL.RGB32UI 
    uniSetter: (gl, loc, val) -> gl.uniform3uiv loc, val



class Vec4Base extends VecBase
  @default: ->
    array = super.default()
    array[3] = 1
    array

export vec4 = gl class Vec4 extends Vec4Base
  @size: 4
  @item: float
  @gl: 
    textureFormat: GL.RGBA32F 
    uniSetter: (gl, loc, val) -> gl.uniform4fv loc, val

export ivec4 = gl class IVec4 extends Vec4Base
  @size: 4
  @item: int
  @gl: 
    textureFormat: GL.RGBA32I 
    uniSetter: (gl, loc, val) -> gl.uniform4iv loc, val

export uivec4 = gl class UIVec4 extends Vec4Base
  @size: 4
  @item: uint
  @gl: 
    textureFormat: GL.RGBA32UI 
    uniSetter: (gl, loc, val) -> gl.uniform4uiv loc, val



class Mat2Base extends VecBase
  @default: ->
    array = super.default()
    array[0] = 1
    array[3] = 1
    array

export mat2 = gl class Mat2 extends Mat2Base
  @size : 4
  @item : float
  @gl   : uniSetter: (gl, loc, val) -> gl.uniformMatrix2fv loc, false, val

export imat2 = gl class IMat2 extends Mat2Base
  @size : 4
  @item : int
  @gl   : uniSetter: (gl, loc, val) -> gl.uniformMatrix2iv loc, false, val

export uimat2 = gl class UIMat2 extends Mat2Base
  @size : 4
  @item : uint
  @gl   : uniSetter: (gl, loc, val) -> gl.uniformMatrix2uiv loc, false, val



class Mat3Base extends VecBase
  @default: ->
    array = super.default()
    array[0] = 1
    array[4] = 1
    array[8] = 1
    array

export mat3 = gl class Mat3 extends Mat3Base
  @size : 9
  @item : float
  @gl   : uniSetter: (gl, loc, val) -> gl.uniformMatrix3fv loc, false, val

export imat3 = gl class IMat3 extends Mat3Base
  @size : 9
  @item : int
  @gl   : uniSetter: (gl, loc, val) -> gl.uniformMatrix3iv loc, false, val

export uimat3 = gl class UIMat3 extends Mat3Base
  @size : 9
  @item : uint
  @gl   : uniSetter: (gl, loc, val) -> gl.uniformMatrix3uiv loc, false, val
  


class Mat4Base extends VecBase
  @default: ->
    array = super.default()
    array[0]  = 1
    array[5]  = 1
    array[10] = 1
    array[15] = 1
    array

  perspective: (fovy, aspect, near, far) -> 
    Matrix.mat4.perspective @array, fovy, aspect, near, far

  invert:              -> @invertFrom @array
  inverted:            -> @clone().invert()
  invertFrom: (matrix) -> Matrix.mat4.invert @array, matrix
  
export mat4 = gl class Mat4 extends Mat4Base
  @size : 16
  @item : float
  @gl   : uniSetter: (gl, loc, val) -> gl.uniformMatrix4fv loc, false, val

export imat4 = gl class IMat4 extends Mat4Base
  @size : 16
  @item : int
  @gl   : uniSetter: (gl, loc, val) -> gl.uniformMatrix4iv loc, false, val

export uimat4 = gl class UIMat4 extends Mat4Base
  @size : 16
  @item : uint
  @gl   : uniSetter: (gl, loc, val) -> gl.uniformMatrix4uiv loc, false, val
  
  
  
  



  
### Smart constructors ###


export value = (a) ->
  switch a.constructor
    when Number then new Float a
    else a

export type = (a) -> 
  switch a.constructor
    when Number   then Float
    else a.type

export toGLSL = (a) -> value(a).toGLSL()
