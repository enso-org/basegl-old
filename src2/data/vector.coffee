
import * as Property from "basegl/object/Property"
import * as Buffer   from 'basegl/data/buffer'



##############
### GLType ###
##############

### Definition ###

class GLType
  constructor: (@id, cfg) ->
    @name = cfg.name
    @code = WebGLRenderingContext[@id]
    if cfg.item
      @item       = cfg.item
      @size       = cfg.size
      @byteSize   = @size * @item.byteSize
      @bufferType = @item.bufferType
    else
      @bufferType = cfg.bufferType    
      @item       = null
      @size       = 1
      @byteSize   = cfg.byteSize || @bufferType.BYTES_PER_ELEMENT

  newBuffer: (elems=1, cfg) ->
    new Buffer.Buffer @bufferType, (elems * @size), cfg

  newBufferfromArray: (array, cfg) ->
    new Buffer.Buffer @bufferType, array, cfg


### Batch preparation ###

typesCfg =
  float        : {name: 'float' , bufferType: Float32Array}
  int          : {name: 'int'   , bufferType: Int32Array}
  float_vec2   : {name: 'vec2'  , item: 'float' , size: 2}
  float_vec3   : {name: 'vec3'  , item: 'float' , size: 3}
  float_vec4   : {name: 'vec4'  , item: 'float' , size: 4}
  int_vec2     : {name: 'ivec2' , item: 'int'   , size: 2}
  int_vec3     : {name: 'ivec3' , item: 'int'   , size: 3}
  int_vec4     : {name: 'ivec4' , item: 'int'   , size: 4}
  float_mat2   : {name: 'mat2'  , item: 'float' , size: 4}
  float_mat3   : {name: 'mat3'  , item: 'float' , size: 9}
  float_mat4   : {name: 'mat4'  , item: 'float' , size: 16}

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

  @default: -> new @ @glType.newBuffer()

  # View another buffer as desired type without copying.
  @view: (base, offset=0) ->
    arr = new View base, offset, @size
    new @ arr

  read:          (ix)      -> @array.read          ix
  write:         (ix,v)    -> @array.write         ix, v
  readMultiple:  (ixs)     -> @array.readMultiple  ixs
  writeMultiple: (ixs, vs) -> @array.writeMultiple ixs, vs

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

  constructor: (@number) -> super()
  @getter 'rawArray', -> new Float32Array [@number]

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


### Smart constructors ###

export vec2 = (args...) => Vec2.from args
export vec3 = (args...) => Vec3.from args
export vec4 = (args...) => Vec4.from args
export mat2 = (args...) => Mat2.from args
export mat3 = (args...) => Mat3.from args
export mat4 = (args...) => Mat4.from args

vec2.type = Vec2
vec3.type = Vec3
vec4.type = Vec4
mat2.type = Mat2
mat3.type = Mat3
mat4.type = Mat4

