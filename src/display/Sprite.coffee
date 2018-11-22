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
import * as TypeClass from 'basegl/lib/TypeClass'
import * as Symbol from 'basegl/display/Symbol'

# import * as Benchmark from 'benchmark'

import _ from 'lodash';
import process from 'process';

benchmark = require('benchmark');
Benchmark = benchmark.runInContext({ _, process });
window.Benchmark = Benchmark;



#############
### UTILS ###
#############

arrayMin = (arr) -> arr.reduce (p, v) -> if p < v then p else v
arrayMax = (arr) -> arr.reduce (p, v) -> if p > v then p else v

# class Foo
#   @_nextID = 0
#   @getID: ->
#     id = @_nextID 
#     @_nextID += 1
#     id

#   constructor: () ->
#     @id = @constructor.getID()


# foo1 = new Foo
# foo2 = new Foo

# console.log foo1
# console.log foo2



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


##########################
### Extensible Configs ###
##########################

param = (name, cfg) ->
  if cfg
    cfg[name] || param(name, cfg._)
  else
    cfg

extend = (base, ext) -> 
  ext._ = base
  ext



#######################
### WebGL constants ###
#######################

CTX = WebGLRenderingContext

export usage = 
  static      : CTX.STATIC_DRAW
  dynamic     : CTX.DYNAMIC_DRAW
  stream      : CTX.STREAM_DRAW
  staticRead  : CTX.STATIC_READ
  dynamicRead : CTX.DYNAMIC_READ
  streamRead  : CTX.STREAM_READ
  staticCopy  : CTX.STATIC_COPY
  dynamicCopy : CTX.DYNAMIC_COPY
  streamCopy  : CTX.STREAM_COPY

webGL =
  glsl:
    precision:
      low:    'lowp'
      medium: 'mediump'
      high:   'highp'
  types: {}


class WebGLType
  constructor: (@name, cfg) ->
    @glslName = cfg.glslName
    @code     = CTX[@name]
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
    

typesCfg =
  float        : {glslName: 'float' , bufferType: Float32Array}
  int          : {glslName: 'int'   , bufferType: Int32Array}
  float_vec2   : {glslName: 'vec2'  , item: 'float' , size: 2}
  float_vec3   : {glslName: 'vec3'  , item: 'float' , size: 3}
  float_vec4   : {glslName: 'vec4'  , item: 'float' , size: 4}
  int_vec2     : {glslName: 'ivec2' , item: 'int'   , size: 2}
  int_vec3     : {glslName: 'ivec3' , item: 'int'   , size: 3}
  int_vec4     : {glslName: 'ivec4' , item: 'int'   , size: 4}
  float_mat2   : {glslName: 'mat2'  , item: 'float' , size: 4}
  float_mat3   : {glslName: 'mat3'  , item: 'float' , size: 9}
  float_mat4   : {glslName: 'mat4'  , item: 'float' , size: 16}





for name,cfg of typesCfg
  if cfg.item?
    cfg.item = webGL.types[cfg.item]
  glName = name.toUpperCase()
  webGL.types[name] = new WebGLType glName, cfg

export webGLType = TypeClass.define2 'WebGLType'
TypeClass.implementStatic2 Number, webGLType, webGL.types.float



###################
### WebGL Utils ###
###################

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
  




################################################################################
################################################################################
################################################################################



##############
### Buffer ###
##############

# Buffer is a wrapper over any array-like object and exposes element read /
# write functions that can be overriden instead of inflexible index-based
# interface.

export class Buffer

  ### Properties ###
  constructor: (@type, args...) ->
    @_array = new @type args...

  @getter 'array'    , -> @_array
  @getter 'buffer'   , -> @_array.buffer
  @getter 'length'   , -> @_array.length
  @getter 'rawArray' , -> @_array

  ### Read / Write ###
  read:          (ix)      -> @_array[ix]
  write:         (ix, v)   -> @_array[ix] = v 
  readMultiple:  (ixs)     -> @_array[ix] for ix from ixs
  writeMultiple: (ixs, vs) -> @_array[ix] = vs[i] for ix,i in ixs

  ### Size Management ###
  resize: (newLength) ->
    newArray  = new @type newLength
    arrayView = if @length <= newLength then @_array else
      new @type @_array.buffer, 0, newLength
    newArray.set arrayView
    @_array = newArray

  ### Redirect ###
  set: (args...) -> @_array.set args...



############
### View ###
############

# View is a wrapper over any buffer-like object allowing to view the array with
# a defined elements shift.

class View

  ### Properties ###
  constructor: (@_array, @_offset=0, @_length=0) ->
  @getter 'array'  , -> @_array
  @getter 'buffer' , -> @_array.buffer
  @getter 'length' , -> @_length
  @getter 'offset' , -> @_offset

  ### Read / Write ###
  read:          (x)    -> @_array.read          (x + @_offset)
  write:         (x, v) -> @_array.write         (x + @_offset), v
  readMultiple:  (x)    -> @_array.readMultiple  (x + @_offset for x from x)
  writeMultiple: (x, v) -> @_array.writeMultiple (x + @_offset for x from x), v

  


##################
### Observable ###
##################

# Observable is a wrapper over any buffer-like object allowing to subscribe to
# changes by monkey-patching its methods.

export class Observable

  ### Properties ###

  constructor: (@_array) -> 
  @getter 'array'    , -> @_array
  @getter 'buffer'   , -> @_array.buffer
  @getter 'length'   , -> @_array.length
  @getter 'rawArray' , -> @_array.rawArray


  ### Read / Write ###

  read:         (ix)  -> @_array.read         ix
  readMultiple: (ixs) -> @_array.readMultiple ixs 
  
  write: (ix, v) -> 
    @_array.write ix, v
    @onChanged ix
  
  writeMultiple: (ixs, vs) ->
    @_array.writeMultiple ixs, vs 
    @onChangedMultiple ixs

  set: (array, offset=0) ->
    @_array.set array, offset
    @onChangedRange offset, array.length


  ### Size Management ###

  resize: (newLength) ->
    oldLength = @_length
    if oldLength != newLength
      @_array.resize newLength
      @onResized oldLength, newLength


  ### Events ###  

  onResized: (oldSize, newSize) ->
  onChanged: (ix) ->

  onChangedMultiple: (ixs) ->
    for ix in ixs
      @onChanged ix
  
  onChangedRange: (offset, length) ->
    for ix in [offset ... offset + length]
      @onChanged ix



################################################################################
################################################################################
################################################################################



############
### Type ###
############

# Type is a base-class for attribute types.

### Abstraction ###

bufferCons = (tp, args...) -> new Buffer webGLType(tp).bufferType, args...

export class Type
  constructor: (@array) ->

  @getter 'length'   , -> webGLType(@constructor).size
  @getter 'buffer'   , -> @array.buffer
  @getter 'rawArray' , -> @array.rawArray
  
  # Smart constructor performing conversions if needed.
  @from: (args) ->
    cfg   = if args then args else @size
    array = bufferCons @, cfg
    new @ array

  # View another buffer as desired type without copying.
  @view: (base, offset=0) ->
    arr = new View base, offset, @size
    new @ arr

  read:          (ix)      -> @array.read          ix
  write:         (ix,v)    -> @array.write         ix, v
  readMultiple:  (ixs)     -> @array.readMultiple  ixs
  writeMultiple: (ixs, vs) -> @array.writeMultiple ixs, vs

  set: (src) ->
    for i in [0 ... webGLType(@constructor).size]
      @write i, (src.read i)
    
Property.swizzleFieldsXYZW2 Type
Property.swizzleFieldsRGBA2 Type
Property.addIndexFields2    Type, 16


### Basic types ###

export class Vec2 extends Type
TypeClass.implementStatic2 Vec2, webGLType, webGL.types.float_vec2

export class Vec3 extends Type
TypeClass.implementStatic2 Vec3, webGLType, webGL.types.float_vec3

export class Vec4 extends Type
TypeClass.implementStatic2 Vec4, webGLType, webGL.types.float_vec4

export class Mat2 extends Type
  @from: (args) ->
    if args
      array = bufferCons @, args
    else
      array = bufferCons @, webGLType(@).size
      array[0] = 1
      array[3] = 1
    new @ array
TypeClass.implementStatic2 Mat2, webGLType, webGL.types.float_mat2

export class Mat3 extends Type
  @from: (args) ->
    if args
      array = bufferCons @, args
    else
      array = bufferCons @, webGLType(@).size
      array[0] = 1
      array[4] = 1
      array[8] = 1
    new @ array
TypeClass.implementStatic2 Mat3, webGLType, webGL.types.float_mat3

export class Mat4 extends Type
  @from: (args) ->
    if args
      array = bufferCons @, args
    else
      array = bufferCons @, webGLType(@).size
      array[0]  = 1
      array[5]  = 1
      array[10] = 1
      array[15] = 1
    new @ array
TypeClass.implementStatic2 Mat4, webGLType, webGL.types.float_mat4


### Smart constructors ###

vec2 = (a) => Vec2.from a
vec3 = (a) => Vec3.from a
vec4 = (a) => Vec4.from a
mat2 = (a) => Mat2.from a
mat3 = (a) => Mat3.from a
mat4 = (a) => Mat4.from a

vec2.type = Vec2
vec3.type = Vec3
vec4.type = Vec4
mat2.type = Mat2
mat3.type = Mat3
mat4.type = Mat4




################################################################################
################################################################################
################################################################################



##################
### Index Pool ###
##################

class Pool
  constructor: (required=0) -> 
    @size      = @_computeSquareSize required
    @free      = []
    @nextIndex = required

  _computeSquareSize: (required) =>
    if required == 0 
      size = 0
    else 
      size = 1
      while true
        if size < required
          size <<= 1
        else break
    size

  reserve: () =>
    n = @free.shift()
    if n != undefined      then return n
    if @nextIndex == @size then @grow()
    n = @nextIndex
    @nextIndex += 1
    n

  dirtySize: () => @nextIndex

  free: (n) =>
    @free.push(n)

  resize: (newSize) => 
    @size = newSize

  growTo: (required) => 
    newSize = @_computeSquareSize required
    oldSize = @size
    if newSize > oldSize 
      @size = newSize
      @onResized oldSize, newSize

  grow: () =>
    oldSize = @size
    newSize = if oldSize == 0 then 1 else oldSize << 1
    @size   = newSize
    @onResized oldSize, newSize

  reserveFromBeginning: (required) =>
    @nextIndex = required
    @growTo required

  ### Events ###
  onResized: (oldSize, newSize) =>



#######################
### BoolLazyManager ###
#######################

class BoolLazyManager

  ### Initialization ###
  constructor: () ->
    @reset()

  reset: -> @isDirty = false

  ### Handlers ###
  handleChanged: () ->
    if not @isDirty
      @isDirty = true
      @onDirty()

  onDirty: ->



#######################
### EnumLazyManager ###
#######################

class EnumLazyManager

  ### Initialization ###
  constructor: () -> 
    @reset()
  @getter 'isDirty', -> @elems.length != 0
  
  reset: -> @elems = []

  ### Handlers ###
  handleChanged: (elem) ->
    wasDirty = @isDirty
    @elems.push elem
    if not wasDirty
      @onDirty()

  onDirty: ->



#########################
### RangedLazyManager ###
#########################

class RangedLazyManager

  ### Initialization ###

  constructor: ->
    @reset()

  reset: ->
    @isDirty = false
    @dirtyRange = 
      min: null
      max: null


  ### Handlers ###

  handleChanged: (ix) ->
    if @isDirty
      if      ix > @dirtyRange.max then @dirtyRange.max = ix
      else if ix < @dirtyRange.min then @dirtyRange.min = ix
    else
      @isDirty        = true
      @dirtyRange.min = ix
      @dirtyRange.max = ix
      @onDirty()

  handleChangedRange: (offset, length) ->
    min = offset
    max = min + length - 1
    if @isDirty
      if max > @dirtyRange.max then @dirtyRange.max = max
      if min < @dirtyRange.min then @dirtyRange.min = min
    else
      @isDirty        = true
      @dirtyRange.min = min
      @dirtyRange.max = max
      @onDirty()

  handleResized: (oldSize, newSize) ->


  ### Events ###
  
  onDirty: ->

  

##############
### Logged ###
##############

export class Logged
  constructor: (cfg={}) ->
    @_label = param('label', cfg) || @constructor.name
    @logger = logger.scoped @_label
  @getter 'label', -> @_label



############
### Lazy ###
############

export class Lazy extends Logged

  constructor: (cfg={}) ->
    super cfg
    @onDirty      = new EventDispatcher    
    @_lazyManager = param('lazyManager',cfg) || new BoolLazyManager 
    @_lazyManager.onDirty = => @setDirty(true)
    
  @getter 'isDirty' , -> @_lazyManager.isDirty  

  setDirty: (force = false) ->
    if force || (not @isDirty)
      @logger.info "Dirty flag set"
      @onDirty.dispatch()

  unsetDirty: ->
    if @isDirty
      @logger.info "Dirty flag unset"
      elems = @_lazyManager.elems
      @_lazyManager.reset()    
      @_unsetDirtyChildren(elems)

  _unsetDirtyChildren: (elems) ->
    for elem in elems
      elem.unsetDirty()



#######################
### EventDispatcher ###
#######################

class EventDispatcher
  constructor: ->
    @_listeners = new Set

  addEventListener: (f) ->
    @_listeners.add f

  removeEventListener: (f) ->
    @_listeners.delete f

  dispatch: (args...) ->
    @_listeners.forEach (f) => f args...

  

#################
### Attribute ###
#################

# Attribute is a data associated with geometry. It is stored as typed array
# buffer under the hood. There are several ways to initialize an Attribute when
# using the Attribute.from smart constructor.

# ### Initialization ###
#
# 1. Type hint initialization. In its shortest form, it takes only the type name
#    and initializes to an empty buffer of the given type.
#
#        position: vec3
#
# 2. Simple initialization. In its shortest form it takes only a list of values
#    and automatically infers the needed type.
#
#        position: [
#         (vec3 [-0.5,  0.5, 0]) ,
#         (vec3 [-0.5, -0.5, 0]) ,
#         (vec3 [ 0.5,  0.5, 0]) ,
#         (vec3 [ 0.5, -0.5, 0]) ]
#
# 3. Explicite initialization. This form allows providing additional parameters.
#
#        position: 
#          usage : usage.static
#          data  : [
#            (vec3 [-0.5,  0.5, 0]) ,
#            (vec3 [-0.5, -0.5, 0]) ,
#            (vec3 [ 0.5,  0.5, 0]) ,
#            (vec3 [ 0.5, -0.5, 0]) ]
#
# 4. Typed array initialization. This form has the best performance, but is less
#    readable than previous ones. Unless you are providing very big chunks of
#    data you will not see any performance difference here. Using this form you
#    have to provide the type explicitly.
#
#        position: 
#          usage : usage.static
#          type  : vec3
#          data  : new Float32Array [
#            -0.5,  0.5, 0 ,
#            -0.5, -0.5, 0 ,
#             0.5,  0.5, 0 ,
#             0.5, -0.5, 0 ]

export class Attribute extends Lazy
  # TODO: to be used when no label provided + make label optional
  @_nextID = 0
  @getID: ->
    id = @_nextID 
    @_nextID += 1
    id

  ### Properties ###

  constructor: (label, @_type, @_size, cfg) -> 
    super
      label       : label
      lazyManager : param('lazyManager',cfg) || new RangedLazyManager 
    
    @logger.info "Allocating space for #{@_size} elements"

    @_scopes  = new Set
    @_default = param('default',cfg)
    @_usage   = param('usage',cfg) || usage.dynamic
    @_data    = new Observable (bufferCons @type, (@size * webGLType(@type).size))

    @_initEventHandlers()

  @getter 'type'    , -> @_type
  @getter 'size'    , -> @_size
  @getter 'data'    , -> @_data
  @getter 'usage'   , -> @_usage
  @getter 'default' , -> @_default


  ### Scope management ###

  registerScope: (scope) ->
    @_scopes.add scope


  ### Initialization ###

  _initEventHandlers: ->
    @_data.onChanged      = (args...) => @_lazyManager.handleChanged      args...
    @_data.onChangedRange = (args...) => @_lazyManager.handleChangedRange args...
    @_data.onResized      = (args...) => @_lazyManager.handleResized      args...

  _unsetDirtyChildren: -> # FIXME


  ### Smart Constructors ###

  # TODO: Function `from` should not expect label as separate argument.
  #       It should be optional argument in its config.
  @from = (label, a) ->
    if a.constructor == Object
      @_from label, a.data, a.type, a
    else
      @_from label, a 

  @_inferArrType = (arr) -> arr[0].constructor
  @_from = (label, a, expType, cfg={}) ->
    if a.constructor == Array
      type = expType || @_inferArrType a
      size = a.length
      attr = new Attribute label, type, size, cfg
      attr.set a
      attr.unsetDirty()
      attr
    else if ArrayBuffer.isView a
      throw "fixme"
      type = expType?.type
      if not type?
        throw "You have to provide explicit type when using TypedArray
              initializator for '#{label}' attribute."
      size = a.length / type.size
      attr = new Attribute label, type, size, cfg
      attr.set a
      attr.unsetDirty()
      attr
    else new Attribute label, a.type, 0, cfg


  ### Size Management ###

  resizeToScopes: ->
    sizes = (scope.size for scope from @_scopes)
    size  = arrayMax sizes
    @resize size

  resize: (newSize) ->
    oldSize = @size
    if oldSize != newSize
      @logger.info "Resizing to handle up to #{newSize} elements"
      @_size = newSize
      @data.resize (@size * webGLType(@type).size)
      

  ### Indexing ###

  read  : (ix)    -> @type.view @data, ix*webGLType(@type).size 
  write : (ix, v) -> @read(ix).set v

  set: (data) ->
    if data.constructor == Array
      typeSize = webGLType(@type).size
      buffer   = bufferCons @type, (typeSize * data.length)
      for i in [0 ... data.length]
        offset = i * typeSize
        buffer.set data[i].rawArray, offset
      @data.set buffer.rawArray
    else if ArrayBuffer.isView data
      @data.set data
    else
      throw "Unsupported attribute initializer '#{data.constructor.name}'"



######################
### AttributeScope ###
######################

export class AttributeScope extends Lazy

  ### Initialization ###

  constructor: (cfg) ->
    super extend cfg,
      lazyManager : new EnumLazyManager
    @data       = {}
    @_dataNames = new Map

    @_initIndexPool()
    @_initValues cfg.data
    
  @getter 'size'       , -> @_indexPool.size
  @getter 'dirtyElems' , -> @_lazyManager.elems

  _initIndexPool: () ->
    @_indexPool = new Pool
    @_indexPool.onResized = @_handlePoolResized.bind @
  
  _initValues: (data) -> 
    for name,attrCfg of data
      @addAttribute name, attrCfg


  ### Attribute Management ###

  add: (data) ->
    ix = @_indexPool.reserve()
    for name, val of data
      @data[name].write(ix,val)

  addAttribute: (name, data) ->
    label = @logger.scope + '.' + name
    attr  = Attribute.from label, data
    @_indexPool.reserveFromBeginning attr.size
    attr.registerScope @
    attr.resizeToScopes()
    @data[name] = attr
    @_dataNames.set attr, name
    attr.onDirty.addEventListener =>
      @_lazyManager.handleChanged name

  _unsetDirtyChildren: (names) ->
    for name in names
      @data[name].unsetDirty()

  ### Handlers ###

  _handlePoolResized: (oldSize, newSize) ->
    @logger.info "Resizing to handle up to #{newSize} elements"
    for name,attr of @data
      attr.resizeToScopes()
      


####################
### UniformScope ###
####################

class UniformScope extends Lazy
  constructor: (cfg) ->
    super cfg
    @data = {}
    @_initValues cfg.data

  _initValues: (data) ->
    for name,val of data
      @logger.info "Initializing '#{name}' variable"
      @data[name] = val
      


################
### Geometry ###
################

export class Geometry extends Lazy

  ### Initialization ###

  constructor: (cfg) ->
    label = param('label',cfg) || "Unnamed"
    super
      label       : "Geometry.#{label}"
      lazyManager : new EnumLazyManager
    
    @logger.group 'Initialization', =>
      @_scope = {}
      @_initScopes cfg

  @getter 'scope'      , -> @_scope
  @getter 'dirtyElems' , -> @_lazyManager.elems

  _initScopes: (cfg) -> 
    scopes = 
      point    : AttributeScope
      instance : AttributeScope
      global   : UniformScope

    for name,cons of scopes
      do (name,cons) =>
        label = "#{@label}.#{name}"
        data  = cfg[name]
        @logger.group "Initializing #{name} scope", =>
          scope         = new cons {label, data}
          @_scope[name] = scope
          @[name]       = scope 
          scope.onDirty.addEventListener =>
            @_lazyManager.handleChanged name

  _unsetDirtyChildren: (names) ->
    for name in names
      @scope[name].unsetDirty()




############
### Mesh ###
############

export class Mesh extends Lazy
  constructor: (geometry, material) ->
    super
      label: "Mesh." + geometry.label
    @geometry = geometry
    @material = material
    @geometry.onDirty.addEventListener =>
      @_lazyManager.handleChanged()

  _unsetDirtyChildren: ->
    @geometry.unsetDirty()


export class Precision
  high = 'high'
  constructor: ->
    @float                = webGL.glsl.precision.medium
    @int                  = webGL.glsl.precision.medium
    @sampler2D            = webGL.glsl.precision.low 
    @samplerCube          = webGL.glsl.precision.low 
    @sampler3D            = webGL.glsl.precision.low   
    @samplerCubeShadow    = webGL.glsl.precision.low         
    @sampler2DShadow      = webGL.glsl.precision.low       
    @sampler2DArray       = webGL.glsl.precision.low      
    @sampler2DArrayShadow = webGL.glsl.precision.low            
    @isampler2D           = webGL.glsl.precision.low  
    @isampler3D           = webGL.glsl.precision.low  
    @isamplerCube         = webGL.glsl.precision.low    
    @isampler2DArray      = webGL.glsl.precision.low       
    @usampler2D           = webGL.glsl.precision.low  
    @usampler3D           = webGL.glsl.precision.low  
    @usamplerCube         = webGL.glsl.precision.low    
    @usampler2DArray      = webGL.glsl.precision.low       
  





vertexShaderSource = '''
void main() {
  gl_Position = matrix * v_position;
}
'''

fragmentShaderSource = '''
void main() {
  out_color = color;
}'''


glslMainPattern = /void +main *\( *\) *{/gm

partitionGLSL = (txt) ->
  mainSplit    = txt.split glslMainPattern
  mainSplitLen = mainSplit.length
  if mainSplitLen > 2 then return
    left: "Multimple main functions found"
  else if mainSplitLen < 2 then return
    right:
      before : txt
      body   : ''
      after  : ''
  else 
    [before, afterMain] = mainSplit
    afterMainSplit      = splitOnClosingBrace afterMain
    if afterMainSplit == null then return 
      left: "Mismatched brackets in main function"
    return
      right: 
        before : before
        body   : afterMainSplit.before
        after  : afterMainSplit.after

splitOnClosingBrace =(txt) ->
  depth = 0
  for i in [0 ... txt.length]
    char = txt[i]
    if      char == '{' then depth += 1
    else if char == '}'
      if depth == 0 then return
        before : txt.substring(0,i)
        after  : txt.substring(i+1)
      else depth -= 1
  return null


class GLSLCodeBuilder
  constructor: (addVersion = true) ->
    @code = ''
    if addVersion
      @addLine '#version 300 es'

  _sectionTitle: (s) ->
    border = '/'.repeat (s.length + 6)
    title  = '\n\n' + border + '\n' + '// ' + s + ' //' + '\n' + border + '\n\n'
    title

  addSection        : (s) -> @code += @_sectionTitle s
  addComment        : (s) -> @addLine "// #{s}"
  addCommentSection : (s) -> @addLine "\n// #{s}\n"
  addText           : (s) -> @code += s
  addLine           : (s) -> @addText "#{s}\n"
  addExpr           : (s) -> @code += s + ';\n'
  addAssignment     : (l, r)    -> @addExpr "#{l} = #{r}"
  addInput          : (args...) -> @addAttr 'in'      , args...
  addOutput         : (args...) -> @addAttr 'out'     , args...
  addUniform        : (args...) -> @addAttr 'uniform' , args...
  addAttr           : (qual, prec, type, name) ->
    p = if prec then " #{prec} " else ' '
    @addExpr "#{qual}#{p}#{type} #{name}"
  buildMain     : (f) ->
    @addLine 'void main() {'
    f?()
    @addLine '}'
    
  



class ShaderBuilder
  constructor: (@material, cfg={}) ->
    @attributes = cfg.attributes || {}
    @uniforms   = cfg.uniforms   || {}
    @outputs    = cfg.outputs    || {}
    @precision =
      vertex   : new Precision
      fragment : new Precision
    @precision.vertex.float = webGL.glsl.precision.high
    @precision.vertex.int   = webGL.glsl.precision.high

  mkVertexName:   (s) -> 'v_' + s
  mkFragmentName: (s) -> s
  # mkOutputName:   (s) -> 'out_' + s

  readVar: (name,cfg) ->
    type = cfg
    prec = null
    if cfg.constructor == Object
      type = cfg.type
      prec = cfg.precision
    {name, type, prec}

  compute: (providedVertexCode, providedFragmentCode) ->
    vertexCode     = new GLSLCodeBuilder
    vertexBodyCode = new GLSLCodeBuilder false
    fragmentCode   = new GLSLCodeBuilder

    addSection = (s) =>
      vertexCode.addSection s
      fragmentCode.addSection s
      
    addSection 'Default precision declarations'
    for type, prec of @precision.vertex
      vertexCode.addExpr "precision #{prec} #{type}"
    for type, prec of @precision.fragment
      fragmentCode.addExpr "precision #{prec} #{type}"

    if @attributes
      addSection 'Attributes shared between vertex and fragment shaders'
      for name,cfg of @attributes
        v = @readVar name, cfg
        fragmentName = @mkFragmentName v.name
        vertexName   = @mkVertexName   v.name
        vertexCode.addInput   v.prec, v.type, vertexName
        vertexCode.addOutput  v.prec, v.type, fragmentName
        fragmentCode.addInput v.prec, v.type, fragmentName
        vertexBodyCode.addAssignment fragmentName, vertexName
    
    if @uniforms
      addSection 'Uniforms'
      for name,cfg of @uniforms
        v = @readVar name, cfg        
        vertexCode.addUniform   v.prec, v.type, v.name
        fragmentCode.addUniform v.prec, v.type, v.name

    if @outputs
      fragmentCode.addSection 'Outputs'
      for name,cfg of @outputs
        v = @readVar name, cfg        
        # name = @mkOutputName v.name
        fragmentCode.addOutput v.prec, v.type, v.name


    # Generating vertex code
    vpart = partitionGLSL providedVertexCode

    generateMain = (f) =>
      vertexCode.addSection "Main entry point"
      vertexCode.buildMain =>
        vertexCode.addCommentSection "Passing values to fragment shader" 
        vertexCode.addText vertexBodyCode.code
        f?()

    if vpart.left
      logger.error "Error while generating vertex shader, reverting to default"
      logger.error vpart.left
      generateMain()
    else
      val = vpart.right
      vertexCode.addSection "Material code"
      vertexCode.addLine val.before
      generateMain =>
        vertexCode.addCommentSection "Material main code"
        vertexCode.addLine val.body
      if val.after.length > 0
        vertexCode.addSection "Material code"      
        vertexCode.addLine val.after


    # Generating fragment code    
    fragmentCode.addSection "Material code"
    fragmentCode.addLine providedFragmentCode
    
    return
      vertex   : vertexCode.code
      fragment : fragmentCode.code
    



class Material extends Lazy
  constructor: (cfg) -> 
    super cfg 
    @_lazyManager.isDirty = true

    @_shaderBuilder = new ShaderBuilder
    @_shader        = null
    @renaming       =
      point:    (s) -> s
      instance: (s) -> "instance_#{s}"
      global:   (s) -> "global_#{s}"
      output:   (s) -> "out_#{s}"
    @_defaultValues =
      point: {}
      instance: {}
    @_values =
      global: {}
      output: {}

  @getter 'shader', ->
    @update()
    @_shader

  _write: (loc, sbloc, name, value) ->
    glType   = webGLType value
    glslType = glType.glslName
    if sbloc[name] != glslType
      sbloc[name] = glslType
      console.log "!!!", sbloc
      @_lazyManager.handleChanged()
    loc[name] = value

  writePointVariable: (name, value) -> 
    n = @renaming.point name
    @_write @_defaultValues.point, @_shaderBuilder.attributes, n, value

  writeInstanceVariable: (name, value) -> 
    n = @renaming.instance name
    @_write @_defaultValues.instance, @_shaderBuilder.attributes, n, value

  writeGlobalVariable: (name, value) -> 
    n = @renaming.global name
    @_write @_values.global, @_shaderBuilder.uniforms, n, value

  writeOutputVariable: (name, value) -> 
    n = @renaming.output name
    @_write @_values.output, @_shaderBuilder.outputs, n, value
  

  update: -> 
    if @isDirty
      @logger.info 'Generating shader'
      vcode = @vertexCode()
      fcode = @fragmentCode()
      @_shader = @_shaderBuilder.compute vcode, fcode
      @unsetDirty()

  _unsetDirtyChildren: ->

  vertexCode   : -> ''
  fragmentCode : -> ''
  

export class RawMaterial extends Material
  constructor: (cfg) ->
    super cfg
    @vertex   = cfg.vertex
    @fragment = cfg.fragment

  vertexCode:   -> @vertex
  fragmentCode: -> @fragment


mat1 = new RawMaterial
  vertex   : vertexShaderSource
  fragment : fragmentShaderSource

console.log mat1.shader
mat1.writePointVariable 'position', (vec4 [0,0,0,0])
mat1.writePointVariable 'color', (vec4 [0,0,0,1])
mat1.writePointVariable 'uv', (vec2 [0,0])
mat1.writeGlobalVariable 'matrix', (mat4 [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0])
mat1.writeOutputVariable 'color', (vec4 [0,0,0,0])
console.log mat1.shader.vertex
console.log mat1.shader.fragment


# sb1 = new ShaderBuilder mat1, 
#   attributes: 
#     foo: 'vec3'
#   outputs:
#     foo: 'vec3'

# {vertex, fragment} = sb1.compute()

# console.warn vertex
# console.warn fragment



###############
### GPUMesh ###
###############

export class GPUMesh extends Lazy
  constructor: (@_ctx, mesh, @_program) ->
    super
      label: "GPU.#{mesh.label}"
    @mesh       = mesh
    @progVarLoc = {}
    @buffer     = {}
    @logger.group "Initializing", =>
      @_initVarLocations()
      @_initVAO()
      @_initBuffers()
      mesh.onDirty.addEventListener =>
        @_lazyManager.handleChanged()

  _initVarLocations: () ->
    @logger.group "Binding variables to shader", =>
      @_initSpaceVarLocations ["point", "instance"], false
      @_initSpaceVarLocations ["global"], true

  _initSpaceVarLocations: (spaceNames, isUniform) ->
    for spaceName in spaceNames
      @logger.group "Binding #{spaceName} variables", =>
        spaceLoc = {}
        @progVarLoc[spaceName] = spaceLoc
        space = @mesh.geometry[spaceName].data
        for name of space
          if isUniform
            loc = @_program.getUniformLocation name
          else 
            loc = @_program.getAttribLocation name
          if loc == -1
            @logger.info "Variable '" + name + "' not used in shader"
          else
            @logger.info "Variable '" + name + "' bound successfully"
            spaceLoc[name] = loc

  _initVAO: () ->
    @logger.group 'Initializing Vertex Array Object (VAO)', =>
      @_vao = @_ctx.createVertexArray()
      @_initAttrs 'point'    , false
      @_initAttrs 'instance' , true

  _initAttrs: (spaceName, instanced) ->
    @logger.group "Initializing #{spaceName} variables", =>
      space = @mesh.geometry[spaceName].data
      @buffer[spaceName] = {}
      withVAO @_ctx, @_vao, =>  
        for name of space
          @logger.info "Binding variable '#{name}'"
          val = space[name]
          loc = @_program.getAttribLocation name
          if loc == -1
            @logger.info "Variable '" + name + "' not used in shader"
          else withNewArrayBuffer @_ctx, (buffer) =>  
            @buffer[spaceName][name] = buffer 

            maxChunkSize  = 4
            normalize     = false
            size          = webGLType(val.type).size
            itemByteSize  = webGLType(val.type).item.byteSize
            itemType      = webGLType(val.type).item.code
            chunksNum     = Math.ceil (size/maxChunkSize)
            chunkSize     = Math.min size, maxChunkSize
            chunkByteSize = chunkSize * itemByteSize
            stride        = chunksNum * chunkByteSize

            for chunkIx in [0 ... chunksNum]
              offByteSize = chunkIx * chunkByteSize
              chunkLoc    = loc + chunkIx
              @_ctx.enableVertexAttribArray chunkLoc
              @_ctx.vertexAttribPointer chunkLoc, chunkSize, itemType,
                                        normalize, stride, offByteSize
              if instanced
                @_ctx.vertexAttribDivisor(chunkLoc, 1)
            @logger.info "Variable '#{name}' bound succesfully using 
                         #{chunksNum} locations"
            
              
              
        
  _initBuffers: () ->
    @logger.group "Initializing buffers", =>
      for spaceName,cfg of @buffer
        space = bufferJS = @mesh.geometry[spaceName]
        @logger.group "Initializing #{spaceName} buffers", =>     
          for varName,bufferGL of cfg
            variable = space.data[varName]
            bufferJS = variable.data.rawArray
            usage    = variable.usage
            @logger.info "Initializing #{varName} buffer"  
            withArrayBuffer @_ctx, bufferGL, =>
              @_ctx.bufferData(@_ctx.ARRAY_BUFFER, bufferJS, usage)

  _unsetDirtyChildren: ->
    @mesh.unsetDirty()

  update: ->
    @logger.group 'Updating', =>
      if @mesh.isDirty
        geometry = @mesh.geometry
        if geometry.isDirty
          for scopeName in geometry.dirtyElems
            @_updateScope geometry, scopeName
            
  _updateScope: (geometry, scopeName) ->
    @logger.group "Updating #{scopeName} scope", =>
      scope       = geometry.scope[scopeName]
      scopeBuffer = @buffer[scopeName]
      for varName in scope.dirtyElems
        bufferGL = scopeBuffer[varName]
        if not bufferGL
          @logger.info "Skipping #{varName} variable (missing in shader)"
        else
          variable      = scope.data[varName]
          bufferJS      = variable.data.rawArray
          dirtyRange    = variable._lazyManager.dirtyRange # FIXME
          srcOffset     = dirtyRange.min
          byteSize      = webGLType(variable.type).item.byteSize
          dstByteOffset = byteSize * srcOffset
          length        = dirtyRange.max - dirtyRange.min + 1
          @logger.info "Updating #{varName} variable (#{length} elements)"
          arrayBufferSubData @_ctx, bufferGL, dstByteOffset, bufferJS, 
                            srcOffset, length 

  draw: (viewProjectionMatrix) ->
    @logger.group "Drawing", =>
      withVAO @_ctx, @_vao, =>
        @_ctx.uniformMatrix4fv(@progVarLoc.global.matrix, false, viewProjectionMatrix)
        pointCount    = @mesh.geometry.point.size
        instanceCount = @mesh.geometry.instance.size
        if instanceCount > 0
          instanceWord = if instanceCount > 1 then "instances" else "instance"
          @logger.info "Drawing #{instanceCount} " + instanceWord
          
          # offset = elemCount * @_SPRITE_VTX_COUNT
          # @_ctx.drawElements(@_ctx.TRIANGLES, offset, @_ctx.UNSIGNED_SHORT, 0)
          @_ctx.drawArraysInstanced(@_ctx.TRIANGLE_STRIP, 0, pointCount, instanceCount)
        else 
          @logger.info "Drawing not instanced geometry"
          @_ctx.drawArrays(@_ctx.TRIANGLE_STRIP, 0, pointCount)
          


export class GPUMeshRegistry extends Lazy
  constructor: ->
    super
      lazyManager : new EnumLazyManager    
    @_meshes = new Set

  @getter 'dirtyMeshes', -> @_lazyManager.elems

  add: (mesh) ->
    @_meshes.add mesh
    mesh.onDirty.addEventListener =>
      @_lazyManager.handleChanged mesh

  update: ->
    if @isDirty
      @logger.group "Updating", =>
        @logger.group "Updating all GPU meshes", =>
          @dirtyMeshes.forEach (mesh) =>
            mesh.update()
        @logger.group "Unsetting dirty flags", =>
          @unsetDirty()
    else @logger.info "Everything up to date"




export test = (ctx, program, viewProjectionMatrix) ->


  # program = utils.createProgramFromSources(ctx,
  #     [vertexShaderSource, fragmentShaderSource])

  geo = new Geometry
    label: "Geo1"
    point:
      position: 
        usage : usage.static
        data  : [
          (vec3 [-100,  100, 0]),
          (vec3 [-100, -100, 0]),
          (vec3 [ 100,  100, 0]),
          (vec3 [ 100, -100, 0])]
      uv: [
        # usage : usage.static
        # data  : [
          (vec2 [0,1]),
          (vec2 [0,0]),
          (vec2 [1,1]),
          (vec2 [1,0])] 
      
      # transform: [
      #   (mat4 [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,100]) ,
      #   (mat4 [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]) ,
      #   (mat4 [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]) ,
      #   (mat4 [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]) ]
      
    instance:
      # color: [
        # (vec4 [1,0,0,1]) ]
      transform: [mat4 [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-100]]

    global:
      matrix: mat4


  meshRegistry = new GPUMeshRegistry

  mesh = new Mesh geo
  m1 = new GPUMesh ctx, mesh, program
  meshRegistry.add m1

  logger.group "FRAME 1", =>
    meshRegistry.update()
  
  logger.group "FRAME 2", =>
    geo.point.data.position.read(1)[0] = 7
    geo.point.data.position.read(1)[0] = 7
    geo.point.data.position.read(1)[1] = 7
    meshRegistry.update()

  logger.group "FRAME 3", =>
    geo.point.data.position.read(1)[0] = 8
    geo.point.data.uv.read(1)[0] = 8
    # geo.instance.data.color.read(0)[0] = 0.7
    meshRegistry.update()

  logger.group "FRAME 4", =>
    meshRegistry.update()

  m1.draw(viewProjectionMatrix)
  

    # console.log "Dirty:", geo.point.dirtyChildren
    # # console.log "position.dirty =", geo.point.attrs.position.dirtyManager.dirtyRange
    # # console.log ">>>", geo.point.attrs.position.size

    # console.log geo.point.attrs.position
    # console.log geo.point.attrs.uv

    # console.warn "END"    
    




# ###############################################################################
# ### OBSOLETE OBSOLETE OBSOLETE OBSOLETE OBSOLETE OBSOLETE OBSOLETE OBSOLETE ###
# ###############################################################################

# class Pool_old 
#   constructor: (@size=0) -> 
#     @free      = []
#     @nextIndex = 0

#   reserve: () =>
#     n = @free.shift()
#     if n != undefined      then return n
#     if @nextIndex == @size then return undefined
#     n = @nextIndex
#     @nextIndex += 1
#     n

#   dirtySize: () => @nextIndex

#   free: (n) =>
#     @free.push(n)

#   resize: (newSize) => 
#     @size = newSize


# WebGL = 
#   SIZE_OF_FLOAT: 4

# BufferUsage = 
#   STATIC_DRAW  : 'STATIC_DRAW'
#   DYNAMIC_DRAW : 'DYNAMIC_DRAW'
#   STREAM_DRAW  : 'STREAM_DRAW'
#   STATIC_READ  : 'STATIC_READ'
#   DYNAMIC_READ : 'DYNAMIC_READ'
#   STREAM_READ  : 'STREAM_READ'
#   STATIC_COPY  : 'STATIC_COPY'
#   DYNAMIC_COPY : 'DYNAMIC_COPY'
#   STREAM_COPY  : 'STREAM_COPY'

# patternFloat32Array = (iterations, pattern) ->
#   chunks = 1 << (iterations - 1)
#   length = chunks * pattern.length
#   arr = new Float32Array length
#   for i in [0 .. pattern.length - 1]
#     arr[i] = pattern[i]
#   p = pattern.length
#   for i in [1 .. iterations - 1]
#     arr.copyWithin p, 0, p
#     p <<= 1
#   arr 

# # xarr = patternFloat32Array 8, [1,2,3,4]
# # console.log xarr


# class Pool_old 
#   constructor: (@size=0) -> 
#     @free      = []
#     @nextIndex = 0

#   reserve: () ->
#     n = @free.shift()
#     if n != undefined      then return n
#     if @nextIndex == @size then return undefined
#     n = @nextIndex
#     @nextIndex += 1
#     n

#   dirtySize: () -> @nextIndex

#   free: (n) ->
#     @free.push(n)

#   resize: (newSize) -> 
#     @size = newSize


# applyDef = (cfg, defCfg) ->
#   if not cfg? then return defCfg
#   for key of defCfg
#     if cfg[key] == undefined
#       cfg[key] = defCfg[key]


# export class Sprite extends Composable
#   @DEFAULT_SIZE = 10
#   cons: (cfg) -> 
#     @mixin displayObjectMixin, [], cfg
#     ds       = Sprite.DEFAULT_SIZE
#     @_id     = null
#     @_buffer = null
#     @configure cfg

#     @_displayObject.onTransformed = => @onTransformed()

#     @variables = 
#       color: new Vector [0,0,0], => 
#         @_buffer.setVariable @_id, 'color', @variables.color


#   onTransformed: () => 
#     if not @isDirty then @_buffer.markDirty @




# export class SpriteBuffer
#   constructor: (@name, @_gl, @_program, @_variables) ->
#     @_SPRITE_IND_COUNT = 4
#     @_SPRITE_VTX_COUNT = 6
#     @_INT_BYTES        = 4
#     @_VTX_DIM          = 3
#     @_VTX_ELEMS        = @_SPRITE_IND_COUNT * @_VTX_DIM
#     @_sizeExp          = 1

#     @_ixPool           = new Pool_old
#     @_vao              = @_gl.createVertexArray()
#     @_locs             = @_program.lookupVariables @_variables  
#     @__dirty           = []
#     @_buffers          = {}

#     @initVAO()
            
#   initVAO: () => @logGroup 'VAO initialization', =>
#     @__indexBuffer = @_gl.createBuffer()

#     @resize(@_sizeExp)
#     varSpace = @_variables.attribute
#     locSpace = @_locs.attribute
#     withVAO @_gl, @_vao, =>  
#       for varName of varSpace
#         @log "Enabling attribute '" + varName + "'"
#         variable = varSpace[varName]
#         varLoc   = locSpace[varName]      
#         buffer   = @_buffers[varName]
#         if varLoc == -1
#           @log "Attribute '" + varName + "' not used in shader"
#         else withArrayBuffer @_gl, buffer.gl, =>   
#           @_gl.enableVertexAttribArray varLoc
#           normalize = false
#           stride    = 0
#           offset    = 0
#           type      = variable.value.webGLRepr.type.glType(@_gl)
#           @_gl.vertexAttribPointer(
#             varLoc, variable.value.webGLRepr.size, type, normalize, stride, offset)
#           if variable.instanced
#             @_gl.vertexAttribDivisor(varLoc, 1)



#   resize: (newSizeExp) =>
#     @_sizeExp = newSizeExp
#     @_size    = 1 << (@_sizeExp - 1)
#     @_ixPool.resize @_size
#     @log "Resizing to 2^" + @_sizeExp + ' elements'

#     # # Indexing geometry
#     # indices = @_buildIndices()
#     # withBuffer @_gl, @_gl.ELEMENT_ARRAY_BUFFER, @__indexBuffer, =>
#     #   @_gl.bufferData(@_gl.ELEMENT_ARRAY_BUFFER, indices, @_gl.STATIC_DRAW)

#     # Updating attribute buffers
#     varSpace = @_variables.attribute   
#     for varName of varSpace
#       variable       = varSpace[varName]
#       # defaultPattern = variable.defaultPattern #FIXME: handle patterns of wring sizes
#       # patternLength  = variable.value.webGLRepr.size * @_SPRITE_IND_COUNT
#       bufferUsage    = variable.usage || BufferUsage.DYNAMIC_DRAW
      
#       bufferJS = null
#       if variable.instanced
#         bufferJS = new Float32Array(variable.value.webGLRepr.size * @_size)
#         if variable.value?
#           bufferJS.fill variable.value
#       else
#         bufferJS = new Float32Array(variable.value.webGLRepr.size * @_SPRITE_IND_COUNT)
#         bufferJS.set variable.initData

#       # bufferJS = if not variable.defaultPattern?
#       #       new Float32Array(patternLength * @_size)
#       #     else patternFloat32Array @_sizeExp, defaultPattern
      
#       buffer = @_buffers[varName]
#       if not buffer?
#         buffer =
#           js: bufferJS
#           gl: @_gl.createBuffer()
#       else
#         bufferJS.set buffer.js
#         buffer.js = bufferJS
#       @_buffers[varName] = buffer

#       withArrayBuffer @_gl, buffer.gl, =>
#         @_gl.bufferData(@_gl.ARRAY_BUFFER, buffer.js, @_gl[bufferUsage])

#   markDirty: (sprite) ->
#     @__dirty.push(sprite)

#   draw: (viewProjectionMatrix) ->
#     @update() 
#     withVAO @_gl, @_vao, =>
#       @_gl.uniformMatrix4fv(@_locs.uniform.matrix, false, viewProjectionMatrix)
#       elemCount = @_ixPool.dirtySize()
#       if elemCount > 0
#         # offset = elemCount * @_SPRITE_VTX_COUNT
#         # @_gl.drawElements(@_gl.TRIANGLES, offset, @_gl.UNSIGNED_SHORT, 0)
#         @_gl.drawArraysInstanced(@_gl.TRIANGLE_STRIP, 0, @_SPRITE_IND_COUNT, 1)

#   create: => @logGroup "Creating sprite", =>
#     ix = @_ixPool.reserve()
#     if not ix?
#       @resize(@_sizeExp * 2)
#       ix = @_ixPool.reserve()
#     @log "New sprite", ix
#     new Sprite
#       buffer : @
#       id     : ix

#   log: (args...) ->
#     logger.info ("[SpriteBuffer." + @name + "]"), args...
  
#   logGroup: (s,f) ->
#     logger.group ("[SpriteBuffer." + @name + "] " + s), f


#   setVariable: (id, name, val) ->
#     # console.log '!!!!!', name, id
#     buffer = @_buffers[name]
#     components = val.components
#     offset = id * 3
#     for componentIx in [0 ... 3]
#       buffer.js[offset + componentIx] = components[componentIx]
#       # console.log "set", (offset + componentIx)

#     dstByteOffset = @_INT_BYTES * offset
#     length        = 3

#     arrayBufferSubData @_gl, buffer.gl, dstByteOffset, buffer.js, 
#                        offset, length 

#   # setVariable: (id, name, val) ->
#   #   console.log '!!!!!', name, id
#   #   buffer = @_buffers[name]

#   #   srcOffset  = id * @_VTX_ELEMS   
#   #   components = val.components

#   #   for vtxIx in [0 ... @_SPRITE_IND_COUNT]
#   #     offset = srcOffset + vtxIx * 3
#   #     for componentIx in [0 ... 3]
#   #       buffer.js[offset + componentIx] = components[componentIx]

#   #   dstByteOffset = @_INT_BYTES * srcOffset
#   #   length        = @_VTX_ELEMS

#   #   arrayBufferSubData @_gl, buffer.gl, dstByteOffset, buffer.js, 
#   #                      srcOffset, length 
                       

#   update: () ->
#     # TODO: check on real use case if bulk update is faster
#     USE_BULK_UPDATE = false

#     dirtyRange = null

#     if USE_BULK_UPDATE
#       dirtyRange =
#         min : undefined
#         max : undefined

#     buffer = @_buffers.position

#     for sprite in @__dirty
#       sprite.update()

#       srcOffset = sprite.id * @_VTX_ELEMS   
#       p = Matrix.vec4.create(); p[3] = 1
#       ds = 0.5

#       p[0] = -ds
#       p[1] = ds 
#       p[2] = 0
#       Matrix.vec4.transformMat4 p, p, sprite.xform
#       buffer.js[srcOffset]     = p[0]
#       buffer.js[srcOffset + 1] = p[1]
#       buffer.js[srcOffset + 2] = p[2]
      
#       p[0] = -ds 
#       p[1] = -ds
#       p[2] = 0
#       Matrix.vec4.transformMat4 p, p, sprite.xform
#       buffer.js[srcOffset + 3] = p[0]
#       buffer.js[srcOffset + 4] = p[1]
#       buffer.js[srcOffset + 5] = p[2]
      
#       p[0] = ds
#       p[1] = ds
#       p[2] = 0
#       Matrix.vec4.transformMat4 p, p, sprite.xform
#       buffer.js[srcOffset + 6] = p[0]
#       buffer.js[srcOffset + 7] = p[1]
#       buffer.js[srcOffset + 8] = p[2]
      
#       p[0] = ds
#       p[1] = -ds
#       p[2] = 0
#       Matrix.vec4.transformMat4 p, p, sprite.xform
#       buffer.js[srcOffset + 9]  = p[0]
#       buffer.js[srcOffset + 10] = p[1]
#       buffer.js[srcOffset + 11] = p[2]

#       console.log ">>>", buffer.js
      
#       if USE_BULK_UPDATE
#         if not (sprite.id >= dirtyRange.min) then dirtyRange.min = sprite.id
#         if not (sprite.id <= dirtyRange.max) then dirtyRange.max = sprite.id
#       else
#         dstByteOffset = @_INT_BYTES * srcOffset
#         length        = @_VTX_ELEMS
#         arrayBufferSubData @_gl, buffer.gl, dstByteOffset, buffer.js, 
#                            srcOffset, length 

#     if USE_BULK_UPDATE
#       srcOffset     = dirtyRange.min * @_VTX_ELEMS
#       dstByteOffset = @_INT_BYTES * srcOffset
#       length        = @_VTX_ELEMS * (dirtyRange.max - dirtyRange.min + 1)
#       arrayBufferSubData @_gl, buffer.gl, dstByteOffset, buffer.js, 
#                          srcOffset, length 

#     __dirty = []
      

