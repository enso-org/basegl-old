import * as Lazy            from 'basegl/object/lazy'
import * as Config from 'basegl/object/config'
import * as Buffer          from 'basegl/core/data/buffer'



CTX = WebGLRenderingContext



webGL =
  glsl:
    precision:
      low:    'lowp'
      medium: 'mediump'
      high:   'highp'
  types: {}
  usage:
    static      : CTX.STATIC_DRAW
    dynamic     : CTX.DYNAMIC_DRAW
    stream      : CTX.STREAM_DRAW
    staticRead  : CTX.STATIC_READ
    dynamicRead : CTX.DYNAMIC_READ
    streamRead  : CTX.STREAM_READ
    staticCopy  : CTX.STATIC_COPY
    dynamicCopy : CTX.DYNAMIC_COPY
    streamCopy  : CTX.STREAM_COPY

rawArray = (a) ->
  if      ArrayBuffer.isView a   then a
  else if a.constructor == Array then a
  else    a.rawArray



arrayMin = (arr) -> arr.reduce (p, v) -> if p < v then p else v
arrayMax = (arr) -> arr.reduce (p, v) -> if p > v then p else v


value = (a) ->
  switch a.constructor
    when Number then new Float a
    else a

xtype = (a) -> 
  switch a.constructor
    when Number   then Float
    else a.type

toGLSL = (a) -> value(a).toGLSL()



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

export class Attribute extends Lazy.Object

  ### Properties ###

  constructor: (cfg) -> 
    super Config.extend cfg,
      lazyManager: new AttributeLazyManager

    @_type    = Config.get('type',cfg) 
    @_size    = Config.get('size',cfg)
    @_default = Config.get('default',cfg) || @_type.default()
    @_usage   = Config.get('usage',cfg)   || webGL.usage.dynamic
    @_scopes  = new Set

    if @_type == undefined then throw 'Type required' 
    if @_size == undefined then throw 'Size required' 

    @logger.info "Allocating space for #{@_size} elements"
    @_data = new Buffer.Observable (@type.glType.newBuffer @size, {default: rawArray @_default})

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

  @_inferArrType = (arr) -> xtype arr[0]
  @from = (cfg) ->
    data  = Config.get 'data'    , cfg
    def   = Config.get 'default' , cfg
    type  = Config.get('type',cfg)?.type
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
      label = Config.get('label', cfg) || 'unnamed'
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
      @data.resize (@size * @type.glType.size)
      

  ### Indexing ###

  read  : (ix)    -> @type.view @data, ix*@type.glType.size 
  write : (ix, v) -> @read(ix).set v

  set: (data) ->
    if data.constructor == Array
      typeSize = @type.glType.size
      buffer   = @type.glType.newBuffer data.length, {default: @_default.rawArray}
      for i in [0 ... data.length]
        val    = value data[i]
        offset = i * typeSize
        console.log "!!!", val
        console.log "!!!", val.rawArray
        buffer.set val.rawArray, offset
      @data.set buffer.rawArray
    else if ArrayBuffer.isView data
      @data.set data
    else
      throw "Unsupported attribute initializer '#{data.constructor.name}'"
