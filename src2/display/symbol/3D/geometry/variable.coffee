import * as Buffer from 'basegl/data/buffer'
import * as Config from 'basegl/object/config'
import * as Lazy   from 'basegl/object/lazy'
import * as GL     from 'basegl/lib/webgl/utils'
import * as Type   from 'basegl/data/vector'
import {Pool}   from 'basegl/data/pool'



webGL =
  glsl:
    precision:
      low:    'lowp'
      medium: 'mediump'
      high:   'highp'
  types: {}

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

toArray = (a) ->
  if      ArrayBuffer.isView a   then a
  else if a.constructor == Array then a
  else    a.array



arrayMin = (arr) -> arr.reduce (p, v) -> if p < v then p else v
arrayMax = (arr) -> arr.reduce (p, v) -> if p > v then p else v





############################
### AttributeLazyManager ###
############################

export class AttributeLazyManager extends Lazy.RangedManager
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

export class Attribute extends Lazy.LazyManager

  ### Properties ###

  constructor: (cfg) -> 
    super Config.extend cfg,
      lazyManager: new AttributeLazyManager

    @_type    = cfg.type 
    @_size    = cfg.size
    @_default = cfg.default || @_type.default()
    @_usage   = cfg.usage   || usage.dynamic
    @_scopes  = new Set

    if @_type == undefined then throw 'Type required' 
    if @_size == undefined then throw 'Size required' 
    @logger.info "Allocating space for #{@_size} elements"
    @_data = new Buffer.Bindable (@type.newBuffer @size, {default: toArray @_default})
    
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

  @_inferArrType = (arr) -> Type.type arr[0]
  @from = (cfg) ->
    data  = cfg.data
    def   = cfg.default
    type  = cfg.type?.type
    array = false
    cons  = data?.constructor
    if ArrayBuffer.isView data
      array = true
      size  = data.length / type.glType.size
    else if cons == Array
      array = true
      type  = type || @_inferArrType data
      size  = data.length
    else if cons == Function
      type = type || data.type
      size = 0
    else
      type = type || data.type
      size = 0
      def  = def || data
    if not type?
      label = cfg.label || 'unnamed'
      throw "Cannot infer '#{label}' attribute type."
    attr = new Attribute Config.extend cfg, {type, size, default: def}
    if array
      attr.set data
      attr.dirty.unset()
    attr


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
      @data.resize (@size * @type.size)
      

  ### Indexing ###

  read  : (ix)    -> @type.view @data, ix*@type.size 
  write : (ix, v) -> @read(ix).set v

  set: (data) ->
    if data.constructor == Array
      typeSize = @type.size
      buffer   = @type.newBuffer data.length, {default: @_default.array}
      for i in [0 ... data.length]
        val    = Type.value data[i]
        offset = i * typeSize
        buffer.set val.array, offset
      @data.set buffer.array
    else if ArrayBuffer.isView data
      @data.set data
    else
      throw "Unsupported attribute initializer '#{data.constructor.name}'"



######################
### AttributeScope ###
######################

class AttributeScopeLazyManager extends Lazy.Manager
  constructor: ->
    super() 
    @_addedAttributes   = []
    @_removedAttributes = []
  @getter 'addedAttributes', -> @_addedAttributes

  setAddedAttribute: (attr) ->
    @_addedAttributes.push attr
    @set()

  setRemovedAttribute: (attr) -> 
    @_removedAttributes.push attr
    @set()

  unset: ->
    @_addedAttributes   = []
    @_removedAttributes = []
    super.unset()


export class AttributeScope extends Lazy.LazyManager

  ### Initialization ###

  constructor: (cfg) ->
    super Config.extend cfg,
      lazyManager : new AttributeScopeLazyManager
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
    for name of data
      @data[name].dirty.unset()
    @dirty.unset()


  ### Attribute Management ###

  add: (data) ->
    @logger.group "Adding new attribute values", =>
      ix = @_indexPool.reserve()
      for name, val of data
        tgt = @data[name]
        if tgt == undefined 
          @logger.info "Skipping inexisting attribute '#{name}'"
        else
          @data[name].write(ix,val)
      ix

  addAttribute: (name, data) ->
    label = @logger.scope + '.' + name
    if data.constructor == Object
      cfg = Config.extend data, {label}
    else
      cfg = {label, data}
    attr  = Attribute.from cfg
    @_indexPool.reserveFromBeginning attr.size
    attr.registerScope @
    attr.resizeToScopes()
    @data[name] = attr
    @_dataNames.set attr, name
    @dirty.setAddedAttribute name


  ### Handlers ###

  _handlePoolResized: (oldSize, newSize) ->
    @logger.info "Resizing scope to handle up to #{newSize} elements"
    for name,attr of @data
      attr.resizeToScopes()
      


####################
### UniformScope ###
####################

export class UniformScope extends Lazy.LazyManager
  constructor: (cfg) ->
    super cfg
    @data = {}
    @_initValues cfg.data

  _initValues: (data) ->
    for name,val of data
      @logger.info "Initializing '#{name}' variable"
      @data[name] = val
      


####################
### GPUAttribute ###
####################

export class GPUAttribute extends Lazy.LazyManager

  ### Properties ###

  constructor: (@_gl, attribute, cfg) ->
    super Config.extend cfg,
      label       : "GPU.#{attribute.label}"
      lazyManager : new Lazy.HierarchicalManager
    @_buffer    = @_gl.createBuffer()
    @_targets   = new Set
    @_attribute = attribute
    @_attribute.dirty.onSet.addEventListener =>
      @dirty.setElem @_attribute
    @_init()

  @getter 'buffer'  , -> @_buffer 
  @getter 'isEmpty' , -> @_targets.size == 0

  
  ### Initialization ###

  _init: ->
    @_initVariables()
    @_updateAll()

  _initVariables: ->
    maxChunkSize   = 4
    size           = @_attribute.type.size
    itemByteSize   = @_attribute.type.item.byteSize
    @itemType      = @_attribute.type.item.gl.code
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
    bufferRaw = @_attribute.data.array
    @logger.info "Updating all elements"
    attrUsage = @_attribute.usage 
    GL.withArrayBuffer @_gl, @_buffer, =>
      @_gl.bufferData(@_gl.ARRAY_BUFFER, bufferRaw, attrUsage)
    @_attribute.dirty.unset()

  update: ->
    if @dirty.isSet 
      if @_attribute.dirty.isResized
        @_updateAll()
      else
        bufferRaw     = @_attribute.data.array
        range         = @_attribute.dirty.range
        srcOffset     = range.min
        byteSize      = @_attribute.type.item.byteSize
        dstByteOffset = byteSize * srcOffset
        length        = range.max - range.min + 1
        @logger.info "Updating #{length} elements"
        GL.arrayBufferSubData @_gl, @_buffer, dstByteOffset, bufferRaw, 
                              srcOffset, length 
        @_attribute.dirty.unset()
      



############################
### GPUAttributeRegistry ###
############################

export class GPUAttributeRegistry extends Lazy.LazyManager
  constructor: (@_gl) ->
    super
      label       : "GPUAttributeRegistry"
      lazyManager : new Lazy.HierarchicalManager     
    @_attrMap = new Map
  @getter 'dirtyAttrs', -> @_dirty.elems  

  bindBuffer: (tgt, attr, f) -> 
    attrGPU = @_attrMap.get attr
    if attrGPU == undefined
      @logger.info "Creating new binding to '#{attr.label}' buffer"
      attrGPU = new GPUAttribute @_gl, attr
      attrGPU.dirty.onSet.addEventListener =>
        @dirty.setElem attrGPU
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
    if @dirty.isSet
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
    