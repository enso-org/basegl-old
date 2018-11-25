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
import {shallowCompare} from 'basegl/object/compare'
import * as Config from 'basegl/object/config'

import {vec2, vec3, vec4, mat2, mat3, mat4} from 'basegl/data/vector'
import * as Buffer          from 'basegl/data/buffer'
import * as Pool            from 'basegl/data/pool'
import * as GL              from 'basegl/gl/utils'
import * as EventDispatcher from 'basegl/event/dispatcher'
import * as Lazy            from 'basegl/object/lazy'
import * as Unique          from 'basegl/object/unique'
import * as Logged          from 'basegl/object/logged'
import {Attribute} from 'basegl/geometry/attribute'


# import * as Benchmark from 'benchmark'

import _ from 'lodash';
import process from 'process';

benchmark = require('benchmark');
Benchmark = benchmark.runInContext({ _, process });
window.Benchmark = Benchmark;


#############
### UTILS ###
#############




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






#######################
### WebGL constants ###
#######################

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








  




################################################################################
################################################################################
################################################################################



################################################################################
################################################################################
################################################################################




################################################################################
################################################################################
################################################################################



















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


export class AttributeScope extends Lazy.Object

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
    @_indexPool = Pool.create()
    @_indexPool.onResized = @_handlePoolResized.bind @
  
  _initValues: (data) -> 
    for name,attrCfg of data
      @addAttribute name, attrCfg
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
    @logger.info "Resizing to handle up to #{newSize} elements"
    for name,attr of @data
      attr.resizeToScopes()
      


####################
### UniformScope ###
####################

class UniformScope extends Lazy.Object
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

export class Geometry extends Lazy.Object

  ### Initialization ###

  constructor: (cfg) ->
    label = Config.get('label',cfg) || "Unnamed"
    super
      label       : "Geometry.#{label}"
      lazyManager : new Lazy.ListManager
    
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
          scope.dirty.onSet.addEventListener =>
            @dirty.set name








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
  constructor: (@material) ->
    @resetVariables()
    @resetPrecision()
    
  resetVariables: ->
    @constants  = {}
    @attributes = {}
    @uniforms   = {}
    @outputs    = {}

  resetPrecision: ->
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
    



class Material extends Lazy.Object
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

export class Mesh extends Lazy.Object
  constructor: (geometry, material) ->
    super
      label: "Mesh." + geometry.label
    @_geometry      = geometry
    @_material      = material
    @_shader        = null
    @_bindings      = {}
    @_shaderBuilder = new ShaderBuilder 
    @geometry.dirty.onSet.addEventListener =>
      @dirty.set()
    @_bindVariables()

  @getter 'geometry' , -> @_geometry
  @getter 'material' , -> @_material
  @getter 'shader'   , -> @_shader
  @getter 'bindings' , -> @_bindings

  _bindVariables: ->
    @logger.group "Binding variables", =>
      {bindings, missing} = @_matchVariables()
      if not shallowCompare @bindings, bindings
        @_bindings = bindings
        @_shaderBuilder.resetVariables()
        @_fillMatches bindings 
        @_fillMissing missing
        @_generateShader()

  _fillMatches: (matches) ->
    for varName, scopeName of matches
      varDef   = @material.variable.input[varName]
      glType   = varDef.glType
      glslType = glType.name
      @logger.info "Using variable '#{varName}' from #{scopeName} scope"
      if scopeName == 'point' || scopeName == 'instance'
        @_shaderBuilder.attributes[varName] = glslType
      else if scopeName == 'object'
        @_shaderBuilder.uniforms[varName] = glslType
      else
        throw "Unsupported scope #{scopeName}"
  
  _fillMissing: (missing) ->
    for varName in missing      
      @logger.info "Using default value for variable '#{varName}'"
      varDef   = @material.variable.input[varName]
      @_shaderBuilder.constants[varName] =
        type  : varDef.glType.name
        value : varDef.toGLSL()

  _matchVariables: ->
    bindings = {}
    missing  = []
    for varName, varDef of @material.variable.input 
      scopeName = @_lookupAttrScope varName
      if scopeName
        bindings[varName] = scopeName
      else
        missing.push varName
    {bindings, missing}
         
  _generateShader: ->
    @logger.info 'Generating shader'
    vcode = @material.vertexCode()
    fcode = @material.fragmentCode()
    @_shader = @_shaderBuilder.compute vcode, fcode
    # console.log @_shader.vertex
    # console.log @_shader.fragment

  _lookupAttrScope: (name) ->
    for scopeName of @geometry.scope
      if @geometry.scope[scopeName].data[name]?
        return scopeName
    return null

  update: ->
    @_bindVariables()

export class Precision
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

class GPUAttribute extends Lazy.Object

  ### Properties ###

  constructor: (@_gl, attribute, cfg) ->
    super Config.extend cfg,
      label       : "GPU.#{attribute.label}"
      lazyManager : new Lazy.HierarchicalManager
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
    GL.withArrayBuffer @_gl, @_buffer, =>
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



class GPUBufferRegistry extends Lazy.Object
  constructor: (@_gl) ->
    super
      lazyManager: new Lazy.HierarchicalManager        
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
    


export class GPUMesh extends Lazy.Object
  constructor: (@_gl, bufferRegistry, mesh) ->
    super
      label: "GPU.#{mesh.label}"
    @_bufferRegistry = bufferRegistry
    @mesh            = mesh
    @_varLoc         = {}
    @buffer          = {}
    @_program        = null
    mesh.dirty.onSet.addEventListener =>
      @dirty.set()
    @_init()

  _init: ->
    @logger.group "Initializing", =>
      @_updateProgram()
      @_initVarLocations()
      @_initVAO()

  _updateProgram: ->
    @logger.group "Compiling shader program", =>
      @_program?.delete()
      shader    = @mesh.shader
      @_program = Program.from @_gl, shader.vertex, shader.fragment
    
  _initVarLocations: () ->
    @logger.group "Binding variables to shader", =>
      @_varLoc = {}
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
        @_varLoc[varName] = loc

  _initVAO: () ->
    @logger.group 'Initializing Vertex Array Object (VAO)', =>
      if @_vao then @_gl.deleteVertexArray @_vao
      @_vao = @_gl.createVertexArray()
      @_bindAttrsToProgram()

  _bindAttrsToProgram: () ->
    GL.withVAO @_gl, @_vao, =>  
      for varName, spaceName of @mesh.bindings
        @bindAttrToProgram spaceName, varName
      
  _bindAttrToProgram: (spaceName, varName) -> 
    GL.withVAO @_gl, @_vao, =>  
      @bindAttrToProgram spaceName, varName

  bindAttrToProgram: (spaceName, varName) -> 
    if spaceName != 'object'
      @logger.group "Binding variable '#{spaceName}.#{varName}'", =>
        space = @mesh.geometry[spaceName].data
        val   = space[varName]
        loc   = @_varLoc[varName]
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

  update: ->
    @logger.group "Update", =>
      oldShader = @mesh.shader
      @mesh.update()
      newShader = @mesh.shader
      if oldShader == newShader
        @logger.info "Shader did not change"
      else
        @_init()
      

  draw: (viewProjectionMatrix) ->
    @logger.group "Drawing", =>
      @_gl.useProgram @_program.glProgram      
      GL.withVAO @_gl, @_vao, =>
        @_gl.uniformMatrix4fv(@_varLoc.matrix, false, viewProjectionMatrix)
        pointCount    = @mesh.geometry.point.length
        instanceCount = @mesh.geometry.instance.length
        if instanceCount > 0
          instanceWord = if instanceCount > 1 then "instances" else "instance"
          @logger.info "Drawing #{instanceCount} " + instanceWord
          
          # offset = elemCount * @_SPRITE_VTX_COUNT
          # @_gl.drawElements(@_gl.TRIANGLES, offset, @_gl.UNSIGNED_SHORT, 0)
          @_gl.drawArraysInstanced(@_gl.TRIANGLE_STRIP, 0, pointCount, instanceCount)
        else 
          @logger.info "Drawing not instanced geometry"
          @_gl.drawArrays(@_gl.TRIANGLE_STRIP, 0, pointCount)
          


export class GPUMeshRegistry extends Lazy.Object
  constructor: ->
    super
      lazyManager : new Lazy.ListManager    
    @_meshes = new Set

  # @getter 'dirtyMeshes', -> @_dirty.elems

  add: (mesh) ->
    @_meshes.add mesh
    mesh.dirty.onSet.addEventListener =>
      @dirty.set mesh

  update: ->
    if @dirty.isDirty
      @logger.group "Updating", =>
        @dirty.elems.forEach (mesh) =>
          mesh.update()
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
        usage : webGL.usage.static
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

      # color: 
      #   type: vec4
      #   default: [1,0,0,1,0,1,0,1]
      
      # transform: [
      #   (mat4 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,100) ,
      #   (mat4 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0) ,
      #   (mat4 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0) ,
      #   (mat4 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0) ]
      
    instance:
      color: vec4
      color: [
        (vec4 1,0,0,1)] # , (vec4 0,1,0,1) ]
      # color: 
      #   data: vec4(1,0,0,1)
      #   default: [1,0,1]
      transform: [mat4(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-100), mat4()]
      # foo: [1,2]

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
    # geo.point.data.position.read(0)[0] = 7
    # console.log geo.instance.data.color
    # geo.instance.addAttribute 'color', 
    #   type: vec4
    #   default: vec4(1,0,0,1)
    # geo.instance.data.color.read(0).rgba = [1,0,0,1]
    # geo.instance.data.color.read(1).rgba = [0,1,0,1]
    meshRegistry.update()
    bufferRegistry.update()
    # meshRegistry.update()
  
  # logger.group "FRAME 2", =>
    # geo.point.data.position.read(0)[0] = 7
  #   geo.point.data.position.read(0)[0] = 7
  #   geo.point.data.position.read(0)[1] = 7
  #   bufferRegistry.update()
  #   # meshRegistry.update()

  # logger.group "FRAME 3", =>
  #   # geo.point.data.position.read(1)[0] = 8
  #   # geo.point.data.uv.read(1)[0] = 8
  #   # geo.instance.add({color: vec4(0,0,1,1)})
  #   geo.instance.add({color: vec4(0,1,0,1), transform:mat4(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,10)})
  #   # geo.instance.add({color: vec4(0,0,0,1)})
  #   # geo.instance.data.color.read(0)[0] = 0.7
  #   bufferRegistry.update()
  #   # meshRegistry.update()

  # logger.group "FRAME 4", =>
  #   bufferRegistry.update()
  #   # meshRegistry.update()


  m1.draw(viewProjectionMatrix)
  