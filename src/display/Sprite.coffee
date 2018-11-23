import * as matrix2 from 'gl-matrix'
import {Program}   from 'basegl/render/webgl'

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



##############
### GLType ###
##############

### Definition ###

class GLType
  constructor: (@id, cfg) ->
    @name = cfg.name
    @code = CTX[@id]
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

  newBuffer: (elems=1) ->
    new Buffer @bufferType, (elems * @size)

  newBufferfromArray: (array) ->
    new Buffer @bufferType, array


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

for name,cfg of typesCfg
  if cfg.item?
    cfg.item = webGL.types[cfg.item]
  glName = name.toUpperCase()
  webGL.types[name] = new GLType glName, cfg





###################
### WebGL Utils ###
###################

withVAO = (gl, vao, f) -> 
  gl.bindVertexArray vao
  out = f()
  gl.bindVertexArray null
  out


withBuffer = (gl, type, buffer, f) -> 
  gl.bindBuffer type, buffer
  out = f()
  gl.bindBuffer type, null
  out

withArrayBuffer = (gl, buffer, f) ->
  withBuffer gl, gl.ARRAY_BUFFER, buffer, f 
  
arrayBufferSubData = (gl, buffer, dstByteOffset, srcData, srcOffset, length) ->
  withArrayBuffer gl, buffer, =>
    gl.bufferSubData gl.ARRAY_BUFFER, dstByteOffset, srcData, srcOffset, length
      

withNewArrayBuffer = (gl, f) ->
  buffer = gl.createBuffer()
  withArrayBuffer gl, buffer, => f buffer
  




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
  @getter 'buffer'   , -> @array.buffer
  @getter 'length'   , -> @array.length
  @getter 'rawArray' , -> @array.rawArray


  ### Read / Write ###

  read:         (ix)  -> @array.read         ix
  readMultiple: (ixs) -> @array.readMultiple ixs 
  
  write: (ix, v) -> 
    @array.write ix, v
    @onChanged ix
  
  writeMultiple: (ixs, vs) ->
    @array.writeMultiple ixs, vs 
    @onChangedMultiple ixs

  set: (array, offset=0) ->
    @array.set array, offset
    @onChangedRange offset, array.length


  ### Size Management ###

  resize: (newLength) ->
    oldLength = @_length
    if oldLength != newLength
      @array.resize newLength
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



##################
### BufferType ###
##################

# BufferType is a base-class for buffer-like attribute types.

### Abstraction ###

export class BufferType
  constructor: (@array) ->
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

export class Float
  @glType: webGL.types.float
  constructor: (@number) ->
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

vec2 = (args...) => Vec2.from args
vec3 = (args...) => Vec3.from args
vec4 = (args...) => Vec4.from args
mat2 = (args...) => Mat2.from args
mat3 = (args...) => Mat3.from args
mat4 = (args...) => Mat4.from args

vec2.type = Vec2
vec3.type = Vec3
vec4.type = Vec4
mat2.type = Mat2
mat3.type = Mat3
mat4.type = Mat4

value = (a) ->
  switch a.constructor
    when Number then new Float a
    else a

toGLSL = (a) -> value(a).toGLSL()


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
  @getter 'dirtySize', -> @nextIndex

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
### EventDispatcher ###
#######################

class EventDispatcher
  constructor         :         -> @_listeners = new Set
  addEventListener    : (f)     -> @_listeners.add    f
  removeEventListener : (f)     -> @_listeners.delete f
  dispatch            : (xs...) -> @_listeners.forEach (f) => f xs...



###################
### LazyManager ###
###################

class LazyManager
  constructor: () ->
    @_onSet   = new EventDispatcher 
    @_onUnset = new EventDispatcher 
    @_isDirty = false
  @getter 'onSet'   , -> @_onSet
  @getter 'onUnset' , -> @_onUnset
  @getter 'isDirty' , -> @_isDirty

  set: ->
    if not @isDirty
      @_isDirty = true
      @onSet.dispatch()

  unset: ->
    if @isDirty
      @_isDirty = false
      @onUnset.dispatch()



#######################
### ListLazyManager ###
#######################

class ListLazyManager extends LazyManager
  constructor: ->
    super() 
    @_elems = []
  @getter 'elems', -> @_elems

  set: (elem) ->
    @_elems.push elem
    super.set()

  unset: ->
    @_elems = []
    super.unset()



###############################
### HierarchicalLazyManager ###
###############################

class HierarchicalLazyManager extends ListLazyManager
  unset: ->
    for elem in @elems
      elem.dirty.unset()
    super.unset()



#########################
### RangedLazyManager ###
#########################

class RangedLazyManager extends LazyManager
  constructor: ->
    super()
    @_range = 
      min: null
      max: null
  @getter 'range', -> @_range

  setIndex: (ix) ->
    if @isDirty
      if      ix > @range.max then @range.max = ix
      else if ix < @range.min then @range.min = ix
    else
      @_range.min = ix
      @_range.max = ix
      @set()

  setRange: (offset, length) ->
    min = offset
    max = min + length - 1
    if @isDirty
      if max > @range.max then @range.max = max
      if min < @range.min then @range.min = min
    else
      @_range.min = min
      @_range.max = max
      @set()


  
##############
### Unique ###
##############

export class Unique
  @_nextID = 0
  @getID: ->
    id = @_nextID 
    @_nextID += 1
    id

  constructor: ->
    @_id = @constructor.getID()
  @getter 'id', -> @_id



##############
### Logged ###
##############

export class Logged extends Unique
  constructor: (cfg={}) ->
    super()
    @_label  = param('label', cfg) || "#{@constructor.name}.#{@id}"
    @_logger = logger.scoped @_label
  @getter 'label'  , -> @_label
  @getter 'logger' , -> @_logger



############
### Lazy ###
############

export class Lazy extends Logged
  constructor: (cfg={}) ->
    super cfg
    @_dirty = param('lazyManager',cfg) || new LazyManager 
    @logger.ifEnabled =>
      @_dirty.onSet.addEventListener   => @logger.info "Dirty flag set"
      @_dirty.onUnset.addEventListener => @logger.info "Dirty flag unset"
  @getter 'dirty', -> @_dirty
    



############################
### AttributeLazyManager ###
############################

class AttributeLazyManager extends RangedLazyManager
  constructor: ->
    super()
    @_isResized = false
  @getter 'isResized', -> @_isResized

  setResized: ->
    @_isResized = true
    @set()

  unset: ->
    @_isResized = false
    super.unset()



#################
### Attribute ###
#################

# Attribute is a data associated with geometry. It is stored as typed array
# buffer under the hood. There are several ways to initialize an Attribute when
# using the Attribute.from smart constructor.

# ### Initialization ###
#
# 1. BufferType hint initialization. In its shortest form, it takes only the type name
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

  ### Properties ###

  constructor: (cfg) -> 
    super extend cfg,
      lazyManager: new AttributeLazyManager
    
    @logger.info "Allocating space for #{@_size} elements"
    @_type    = param('type',cfg)    || throw 'Type required' 
    @_size    = param('size',cfg)    || throw 'Size required'
    @_default = param('default',cfg) || null
    @_usage   = param('usage',cfg)   || usage.dynamic
    @_scopes  = new Set
    @_data    = new Observable (@type.glType.newBuffer @size)

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
    @data.onChanged      = (args...) => @dirty.setIndex   args...
    @data.onChangedRange = (args...) => @dirty.setRange   args...
    @data.onResized      = (args...) => @dirty.setResized args...


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
      attr = new Attribute extend cfg, {label, type, size}
      attr.set a
      attr.dirty.unset()
      attr
    else if ArrayBuffer.isView a
      type = expType?.type
      if not type?
        throw "You have to provide explicit type when using TypedArray
              initializator for '#{label}' attribute."
      size = a.length / type.glType.size
      attr = new Attribute extend cfg, {label, type, size}
      attr.set a
      attr.dirty.unset()
      attr
    else new Attribute extend cfg,
      label : label
      type  : a.type
      size  : 0



  ### Size Management ###

  resizeToScopes: ->
    sizes = (scope.size for scope from @_scopes)
    size  = arrayMax sizes
    @_resize size

  _resize: (newSize) ->
    oldSize = @size
    if oldSize != newSize
      @logger.info "Resizing to handle up to #{newSize} elements"
      @_size = newSize
      @data.resize (@size * @type.glType.size)
      

  ### Indexing ###

  read  : (ix)    -> @type.view @data, ix*@type.glType.size 
  write : (ix, v) -> @read(ix).set v

  set: (data) ->
    if data.constructor == Array
      typeSize = @type.glType.size
      buffer   = @type.glType.newBuffer data.length
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

export class AttributeScope extends Logged

  ### Initialization ###

  constructor: (cfg) ->
    super extend cfg,
      lazyManager : new ListLazyManager
    @data       = {}
    @_dataNames = new Map

    @_initIndexPool()
    @_initValues cfg.data
    
  @getter 'size'   , -> @_indexPool.size
  @getter 'length' , -> @_indexPool.dirtySize

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


  ### Handlers ###

  _handlePoolResized: (oldSize, newSize) ->
    @logger.info "Resizing to handle up to #{newSize} elements"
    for name,attr of @data
      attr.resizeToScopes()
      


####################
### UniformScope ###
####################

class UniformScope extends Logged
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

export class Geometry extends Logged

  ### Initialization ###

  constructor: (cfg) ->
    label = param('label',cfg) || "Unnamed"
    super
      label       : "Geometry.#{label}"
      lazyManager : new ListLazyManager
    
    @logger.group 'Initialization', =>
      @_scope = {}
      @_initScopes cfg

  @getter 'scope'      , -> @_scope
  # @getter 'dirtyElems' , -> @dirty.elems

  _initScopes: (cfg) -> 
    scopes = 
      point    : AttributeScope
      # polygon  : TODO (triangles)
      instance : AttributeScope
      object   : UniformScope
      # global   : TODO (shared between objects)

    for name,cons of scopes
      do (name,cons) =>
        label = "#{@label}.#{name}"
        data  = cfg[name]
        @logger.group "Initializing #{name} scope", =>
          scope         = new cons {label, data}
          @_scope[name] = scope
          @[name]       = scope 
          # scope.onSet.addEventListener =>
          #   @dirty.set name








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


class GLSLBuilder
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
  addDefinition     : (t, n, v) -> @addAssignment "#{t} #{n}", v
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
    @constants  = cfg.constants  || {}
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

  readVar: (name,cfg) ->
    type = cfg
    prec = null
    if cfg.constructor == Object
      type = cfg.type
      prec = cfg.precision
    {name, type, prec}

  compute: (providedVertexCode, providedFragmentCode) ->
    vertexCode     = new GLSLBuilder
    vertexBodyCode = new GLSLBuilder false
    fragmentCode   = new GLSLBuilder

    addSection = (s) =>
      vertexCode.addSection s
      fragmentCode.addSection s
      
    addSection 'Default precision declarations'
    for type, prec of @precision.vertex
      vertexCode.addExpr "precision #{prec} #{type}"
    for type, prec of @precision.fragment
      fragmentCode.addExpr "precision #{prec} #{type}"

    if @constants
      addSection 'Constants'
      for name,cfg of @constants
        vertexName   = @mkVertexName   name
        fragmentName = @mkFragmentName name
        vertexCode.addDefinition   cfg.type, vertexName   , cfg.value
        fragmentCode.addDefinition cfg.type, fragmentName , cfg.value

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
        prec = 'mediump' # FIXME! We cannot get mismatch of prec between vertex and fragment shader!
        vertexCode.addUniform   prec, v.type, v.name
        fragmentCode.addUniform prec, v.type, v.name

    if @outputs
      fragmentCode.addSection 'Outputs'
      for name,cfg of @outputs
        v = @readVar name, cfg        
        fragmentCode.addOutput v.prec, v.type, v.name

    
    ### Generating vertex code ###

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


    ### Generating fragment code ###

    fragmentCode.addSection "Material code"
    fragmentCode.addLine providedFragmentCode
    
    return
      vertex   : vertexCode.code
      fragment : fragmentCode.code
    



class Material extends Lazy
  constructor: (cfg) -> 
    super cfg 
    @_variable = 
      input  : cfg.input  || {}
      output : cfg.output || {}

  @getter 'variable', -> @_variable

    # @dirty.isDirty = true

  #   @_shaderBuilder = new ShaderBuilder
  #   @_shader        = null
  #   @renaming       =
  #     point:    (s) -> "point_#{s}"
  #     instance: (s) -> "instance_#{s}"
  #     object:   (s) -> "object_#{s}"
  #     output:   (s) -> "out_#{s}"
  #   @_defaultValues =
  #     point: {}
  #     instance: {}
  #   @_values =
  #     object: {}
  #     output: {}

  # @getter 'shader', ->
  #   @update()
  #   @_shader

  # _write: (loc, sbloc, name, value) ->
  #   glType   = webGLType_old value
  #   glslType = glType.name
  #   if sbloc[name] != glslType
  #     sbloc[name] = glslType
  #     @dirty.set()
  #   loc[name] = value

  # writePointVariable: (name, value) -> 
  #   n = @renaming.point name
  #   @_write @_defaultValues.point, @_shaderBuilder.attributes, n, value

  # writeInstanceVariable: (name, value) -> 
  #   n = @renaming.instance name
  #   @_write @_defaultValues.instance, @_shaderBuilder.attributes, n, value

  # writeObjectVariable: (name, value) -> 
  #   n = @renaming.object name
  #   @_write @_values.object, @_shaderBuilder.uniforms, n, value

  # writeOutputVariable: (name, value) -> 
  #   n = @renaming.output name
  #   @_write @_values.output, @_shaderBuilder.outputs, n, value
  

  # update: -> 
  #   if @isDirty
  #     @logger.info 'Generating shader'
  #     vcode = @vertexCode()
  #     fcode = @fragmentCode()
  #     @_shader = @_shaderBuilder.compute vcode, fcode
  #     @dirty.unset()


  vertexCode   : -> ''
  fragmentCode : -> ''
  

export class RawMaterial extends Material
  constructor: (cfg) ->
    super cfg
    @vertex   = cfg.vertex
    @fragment = cfg.fragment

  vertexCode:   -> @vertex
  fragmentCode: -> @fragment






############
### Mesh ###
############

export class Mesh extends Logged
  constructor: (geometry, material) ->
    super
      label: "Mesh." + geometry.label
    @_geometry      = geometry
    @_material      = material
    @_shader        = null
    @_bindings      = {}
    @_shaderBuilder = new ShaderBuilder 
    # @geometry.onSet.addEventListener =>
    #   @dirty.set()
    @_bindVariables()
    @_generateShader()

  @getter 'geometry' , -> @_geometry
  @getter 'material' , -> @_material
  @getter 'shader'   , -> @_shader
  @getter 'bindings' , -> @_bindings

  _bindVariables: ->
    for varName, varDef of @material.variable.input 
      glType   = varDef.glType
      glslType = glType.name
      @logger.info "Binding variable '#{varName}'"
      scopeName = @_lookupAttrScope varName
      if scopeName
        @logger.info "Using variable '#{varName}' from #{scopeName} scope"
        @_bindings[varName] = scopeName
        if scopeName == 'point' || scopeName == 'instance'
          @_shaderBuilder.attributes[varName] = glslType
        else if scopeName == 'object'
          @_shaderBuilder.uniforms[varName] = glslType
        else
          throw "Unsupported scope #{scopeName}"
      else
        @_shaderBuilder.constants[varName] =
          type  : varDef.glType.name
          value : varDef.toGLSL()
         

  _generateShader: ->
    @logger.info 'Generating shader'
    vcode = @material.vertexCode()
    fcode = @material.fragmentCode()
    @_shader = @_shaderBuilder.compute vcode, fcode
    console.log @_shader.vertex
    console.log @_shader.fragment

  _lookupAttrScope: (name) ->
    for scopeName of @geometry.scope
      if @geometry.scope[scopeName].data[name]?
        return scopeName
    return null


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
  

  
###############
### GPUMesh ###
###############

class GPUAttribute extends Lazy

  ### Properties ###

  constructor: (@_gl, attribute, cfg) ->
    super extend cfg,
      label       : "GPU.#{attribute.label}"
      lazyManager : new HierarchicalLazyManager
    @_buffer    = @_gl.createBuffer()
    @_targets   = new Set
    @_attribute = attribute
    @_attribute.dirty.onSet.addEventListener =>
      @dirty.set @_attribute
    @_init()

  @getter 'buffer'  , -> @_buffer 
  @getter 'isEmpty' , -> @_targets.size == 0

  
  ### Initialization ###

  _init: ->
    @_initVariables()
    @_updateAll()

  _initVariables: ->
    maxChunkSize   = 4
    size           = @_attribute.type.glType.size
    itemByteSize   = @_attribute.type.glType.item.byteSize
    @itemType      = @_attribute.type.glType.item.code
    @chunksNum     = Math.ceil (size/maxChunkSize)
    @chunkSize     = Math.min size, maxChunkSize
    @chunkByteSize = @chunkSize * itemByteSize
    @stride        = @chunksNum * @chunkByteSize


  ### API ###

  addTarget    : (a) -> @_targets.add    a
  removeTarget : (a) -> @_targets.delete a
  dispose      :     -> @_gl.deleteBuffer @_buffer

  bindToLoc: (loc, instanced=false) ->
    normalize = false
    for chunkIx in [0 ... @chunksNum]
      offByteSize = chunkIx * @chunkByteSize
      chunkLoc    = loc + chunkIx
      @_gl.enableVertexAttribArray chunkLoc
      @_gl.vertexAttribPointer chunkLoc, @chunkSize, @itemType,
                               normalize, @stride, offByteSize
      if instanced then @_gl.vertexAttribDivisor(chunkLoc, 1)

  _updateAll: () ->
    @logger.info "Updating all elements"    
    bufferRaw = @_attribute.data.rawArray
    usage     = @_attribute.usage
    withArrayBuffer @_gl, @_buffer, =>
      @_gl.bufferData(@_gl.ARRAY_BUFFER, bufferRaw, usage)

  update: ->
    if @dirty.isDirty 
      if @_attribute.dirty.isResized
        @_updateAll()
      else
        bufferRaw     = @_attribute.data.rawArray
        range         = @_attribute.dirty.range
        srcOffset     = range.min
        byteSize      = @_attribute.type.glType.item.byteSize
        dstByteOffset = byteSize * srcOffset
        length        = range.max - range.min + 1
        @logger.info "Updating #{length} elements"
        arrayBufferSubData @_gl, @_buffer, dstByteOffset, bufferRaw, 
                          srcOffset, length 



class GPUBufferRegistry extends Lazy
  constructor: (@_gl) ->
    super
      lazyManager: new HierarchicalLazyManager        
    @_attrMap = new Map
  @getter 'dirtyAttrs', -> @_dirty.elems  

  bindBuffer: (tgt, attr, f) -> 
    attrGPU = @_attrMap.get attr
    if attrGPU == undefined
      @logger.info "Creating new binding to '#{attr.label}' buffer"
      attrGPU = new GPUAttribute @_gl, attr
      attrGPU.dirty.onSet.addEventListener =>
        @_dirty.set attrGPU
    attrGPU.addTarget tgt
    buffer = attrGPU.buffer
    @_withArrayBuffer buffer, => f attrGPU    

  unbindBuffer: (tgt, attr) ->
    attrGPU = @_attrMap.get attr
    if attrGPU != undefined
      attrGPU.removeTarget tgt
      if attrGPU.isEmpty
        @logger.info "Removing binding to '#{attr.label}' buffer"
        attrGPU.dispose()
        @_attrMap.delete attr

  update: ->
    if @dirty.isDirty
      @logger.group "Updating", =>
        @dirtyAttrs.forEach (attr) =>
          attr.update()
        @logger.group "Unsetting dirty flags", =>
          @dirty.unset()
    else @logger.info "Everything up to date"

  _unsetDirtyChildren: (elems) ->
    for elem in elems
      elem.dirty.unset()
  
  _withBuffer: (type, buffer, f) -> 
    @_gl.bindBuffer type, buffer
    out = f()
    @_gl.bindBuffer type, null
    out

  _withArrayBuffer: (buffer, f) ->
    @_withBuffer WebGLRenderingContext.ARRAY_BUFFER, buffer, f 
    


export class GPUMesh extends Logged
  constructor: (@_gl, bufferRegistry, mesh) ->
    super
      label: "GPU.#{mesh.label}"
    @_bufferRegistry = bufferRegistry
    @mesh            = mesh
    @varLoc          = {}
    @buffer          = {}
    @_program        = null
    @logger.group "Initializing", =>
      @_updateProgram()
      @_initVarLocations()
      @_initVAO()
      # mesh.onSet.addEventListener =>
      #   @_dirty.set()

  _updateProgram: ->
    @logger.group "Compiling shader program", =>
      shader = @mesh.shader
      @_program = Program.from @_gl, shader.vertex, shader.fragment
    
  _initVarLocations: () ->
    @logger.group "Binding variables to shader", =>
      for varName, spaceName of @mesh.bindings
        @_initSpaceVarLocation spaceName, varName

  _initSpaceVarLocation: (spaceName, varName) ->
      if spaceName == 'object'
        loc = @_program.getUniformLocation varName
      else 
        loc = @_program.getAttribLocation "v_#{varName}"
      if loc == -1
        @logger.info "Variable '" + varName + "' not used in shader"
      else
        @logger.info "Variable '" + varName + "' bound successfully"
        @varLoc[varName] = loc

  _initVAO: () ->
    @logger.group 'Initializing Vertex Array Object (VAO)', =>
      @_vao = @_gl.createVertexArray()
      @_bindAttrsToProgram()

  _bindAttrsToProgram: () ->
    withVAO @_gl, @_vao, =>  
      for varName, spaceName of @mesh.bindings
        @bindAttrToProgram spaceName, varName
      
  _bindAttrToProgram: (spaceName, varName) -> 
    withVAO @_gl, @_vao, =>  
      @bindAttrToProgram spaceName, varName

  bindAttrToProgram: (spaceName, varName) -> 
    if spaceName != 'object'
      @logger.group "Binding variable '#{spaceName}.#{varName}'", =>
        space = @mesh.geometry[spaceName].data
        val   = space[varName]
        loc   = @varLoc[varName]
        if not @buffer[spaceName]?
          @buffer[spaceName] = {}
        if loc != undefined
          @_bufferRegistry.bindBuffer @, val, (bufferx) =>
            buffer    = bufferx._buffer
            instanced = (spaceName == 'instance')
            @buffer[spaceName][varName] = buffer 
            bufferx.bindToLoc loc, instanced 
            @logger.info "Variable bound succesfully using 
                         #{bufferx.chunksNum} locations"

  _unsetDirtyChildren: ->
    @mesh.dirty.unset()

  draw: (viewProjectionMatrix) ->
    @logger.group "Drawing", =>
      @_gl.useProgram @_program.glProgram      
      withVAO @_gl, @_vao, =>
        @_gl.uniformMatrix4fv(@varLoc.matrix, false, viewProjectionMatrix)
        pointCount    = @mesh.geometry.point.length
        instanceCount = @mesh.geometry.instance.length
        console.log ">>>", pointCount, instanceCount
        if instanceCount > 0
          instanceWord = if instanceCount > 1 then "instances" else "instance"
          @logger.info "Drawing #{instanceCount} " + instanceWord
          
          # offset = elemCount * @_SPRITE_VTX_COUNT
          # @_gl.drawElements(@_gl.TRIANGLES, offset, @_gl.UNSIGNED_SHORT, 0)
          @_gl.drawArraysInstanced(@_gl.TRIANGLE_STRIP, 0, pointCount, instanceCount)
        else 
          @logger.info "Drawing not instanced geometry"
          @_gl.drawArrays(@_gl.TRIANGLE_STRIP, 0, pointCount)
          


export class GPUMeshRegistry extends Logged
  constructor: ->
    super()
      # lazyManager : new ListLazyManager    
    @_meshes = new Set

  # @getter 'dirtyMeshes', -> @_dirty.elems

  add: (mesh) ->
    @_meshes.add mesh
    # mesh.onSet.addEventListener =>
    #   @_dirty.set mesh

  update: ->
    # if @dirty.isDirty
    #   @logger.group "Updating", =>
    #     @logger.group "Updating all GPU meshes", =>
    #       @dirtyMeshes.forEach (mesh) =>
    #         mesh.update()
    #     @logger.group "Unsetting dirty flags", =>
    #       @dirty.unset()
    # else @logger.info "Everything up to date"




export test = (ctx, viewProjectionMatrix) ->


  # program = utils.createProgram(ctx,
  #     [vertexShaderSource, fragmentShaderSource])

  geo = new Geometry
    label: "Geo1"
    point:
      position: 
        usage : usage.static
        data  : [
          (vec3 -100,  100, 0),
          (vec3 -100, -100, 0),
          (vec3  100,  100, 0),
          (vec3  100, -100, 0)]
      uv: [
        # usage : usage.static
        # data  : [
          (vec2 0,1),
          (vec2 0,0),
          (vec2 1,1),
          (vec2 1,0)] 

      # color: 
      #   type: vec4
      #   data: new Float32Array [
      #     1,0,0,1,
      #     0,1,0,1,
      #     0,0,1,1,
      #     1,1,1,1]

      # color: [
      #   (vec4 1,0,0,1),
      #   (vec4 0,1,0,1),
      #   (vec4 0,0,1,1),
      #   (vec4 1,1,1,1)
      # ]
      
      # transform: [
      #   (mat4 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,100) ,
      #   (mat4 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0) ,
      #   (mat4 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0) ,
      #   (mat4 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0) ]
      
    instance:
      color: [
        (vec4 1,0,0,1)] # , (vec4 0,1,0,1) ]
      transform: [mat4(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-100)]

    object:
      matrix: mat4

  bufferRegistry = new GPUBufferRegistry ctx
  meshRegistry = new GPUMeshRegistry


  vertexShaderSource = '''
  void main() {
    gl_Position = matrix * v_position;
    gl_Position.x += v_transform[3][3];
  }
  '''

  fragmentShaderSource = '''
  out vec4 output_color;  
  void main() {
    output_color = color;
  }'''

  mat1 = new RawMaterial
    vertex   : vertexShaderSource
    fragment : fragmentShaderSource
    input:
      position  : vec4()
      transform : mat4()
      matrix    : mat4()
      color     : vec4 0,1,0,1
  mesh = new Mesh geo, mat1

  m1 = new GPUMesh ctx, bufferRegistry, mesh
  meshRegistry.add m1



  # console.log mat1.shader
  # mat1.writePointVariable 'position', (vec4 [0,0,0,0])
  # mat1.writePointVariable 'color', (vec4 [0,0,0,1])
  # mat1.writePointVariable 'uv', (vec2 [0,0])
  # mat1.writeObjectVariable 'matrix', (mat4 [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0])
  # mat1.writeOutputVariable 'color', (vec4 [0,0,0,0])
  # console.log mat1.shader.vertex
  # console.log mat1.shader.fragment

  logger.group "FRAME 1", =>
    bufferRegistry.update()
    # meshRegistry.update()
  
  logger.group "FRAME 2", =>
    geo.point.data.position.read(0)[0] = 7
    geo.point.data.position.read(0)[0] = 7
    geo.point.data.position.read(0)[1] = 7
    bufferRegistry.update()
    # meshRegistry.update()

  logger.group "FRAME 3", =>
    # geo.point.data.position.read(1)[0] = 8
    # geo.point.data.uv.read(1)[0] = 8
    # geo.instance.add({color: vec4(0,0,1,1)})
    geo.instance.add({color: vec4(0,1,0,1), transform:mat4(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,10)})
    geo.instance.add({color: vec4(0,0,0,1)})
    # geo.instance.data.color.read(0)[0] = 0.7
    bufferRegistry.update()
    # meshRegistry.update()

  logger.group "FRAME 4", =>
    bufferRegistry.update()
    # meshRegistry.update()


  m1.draw(viewProjectionMatrix)
  
  # console.log geo.instance.data.transform.read(0).array._array._array._array
  # console.log geo.point.data.position.read(1).array._array._array._array
  # console.log geo.point.data.position
  # console.log geo.point.data.color

    # console.log "Dirty:", geo.point.dirtyChildren
    # # console.log "position.dirty =", geo.point.attrs.position.dirtyManager.range
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
#     if not @dirty.isDirty then @_buffer.markDirty @




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

#     range = null

#     if USE_BULK_UPDATE
#       range =
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
#         if not (sprite.id >= range.min) then range.min = sprite.id
#         if not (sprite.id <= range.max) then range.max = sprite.id
#       else
#         dstByteOffset = @_INT_BYTES * srcOffset
#         length        = @_VTX_ELEMS
#         arrayBufferSubData @_gl, buffer.gl, dstByteOffset, buffer.js, 
#                            srcOffset, length 

#     if USE_BULK_UPDATE
#       srcOffset     = range.min * @_VTX_ELEMS
#       dstByteOffset = @_INT_BYTES * srcOffset
#       length        = @_VTX_ELEMS * (range.max - range.min + 1)
#       arrayBufferSubData @_gl, buffer.gl, dstByteOffset, buffer.js, 
#                          srcOffset, length 

#     __dirty = []
      

