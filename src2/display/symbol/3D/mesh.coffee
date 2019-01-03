import * as GL       from 'basegl/lib/webgl/utils'
import * as Lazy     from 'basegl/object/lazy'
import * as Variable from 'basegl/display/symbol/3D/geometry/variable'
import * as Material from 'basegl/display/symbol/3D/material'
import * as _        from 'lodash'

import {DisplayObject}  from 'basegl/display/object'
import {shallowCompare} from 'basegl/object/compare'
import {Program}        from 'basegl/render/webgl'
import {texture}        from 'basegl/data/vector'


############
### Mesh ###
############

compareAttrScopeMaps = (map1, map2) -> 
  compareMapsWith map1, map2, (val1, val2) =>
    (val1.scope != val2.scope) || (val1.type != val2.type)

compareMapsWith = (map1, map2, comp) -> 
  if map1.size != map2.size then return false
  map1.forEach (val1,key) =>
    val2 = map2.get key
    if not comp(val1,val2) then return false
  return true 


export class Mesh extends DisplayObject
  @mixin Lazy.LazyManager

  constructor: (geometry, material) ->
    super()
    @mixins.constructor
      label       : "Mesh." + geometry.label
      lazyManager : new Lazy.HierarchicalManager 
    @_geometry      = geometry
    @_material      = material
    @_shader        = null
    @_exposeAllVars = true
    @_shaderBuilder = new Material.ShaderBuilder 
    @_variables     =
      bound:   new Map
      unbound: []
    @geometry.dirty.onSet.addEventListener => @dirty.setElem @geometry
    @material.dirty.onSet.addEventListener => @dirty.setElem @material
    @_bindVariables()

  @getter 'geometry' , -> @_geometry
  @getter 'material' , -> @_material
  @getter 'shader'   , -> @_shader

  # Every Mesh-like object is supposed to provide 'mesh' field. This way all
  # API's can just invoke it while adding it to the stage.
  @getter 'mesh', -> @ 

  _bindVariables: ->
    newVariables    = @_matchVariables()
    materialChanged = @material.dirty.isSet
    bindingsChanged = not compareAttrScopeMaps @variables.bound, 
                      newVariables.bound
    if bindingsChanged || materialChanged
      @logger.group "Binding variables", =>
        @_variables = newVariables
        outputs     = {}
        for name,output of @material.variable.output
          outputs[name] = output.gl.name

        @_shaderBuilder.resetVariables()
        @_shaderBuilder.locals  = @material.variable.locals
        @_shaderBuilder.outputs = outputs
        @_registerBoundVariables   @variables.bound 
        @_registerUnboundVariables @variables.unbound
        @_generateShader()

  _registerBoundVariables: (matches) ->
    matches.forEach (cfg, varName) =>
      glType   = cfg.type.gl
      glslType = glType.name
      @logger.info "Using variable '#{varName}' from #{cfg.scope} scope"
      if cfg.scope == 'point' || cfg.scope == 'instance'
        @_shaderBuilder.attributes[varName] = glslType
      else if cfg.scope == 'object'
        @_shaderBuilder.uniforms[varName] = glslType
      else
        throw "Unsupported scope #{cfg.scope}"
  
  _registerUnboundVariables: (unbound) ->
    for varName in unbound      
      @logger.info "Creating uniform for not bound variable '#{varName}'"
      varDef = @material.variable.input[varName]
      @_shaderBuilder.uniforms[varName] = varDef.type.gl.name

  _matchVariables: ->
    bound   = if @exposeAllVars then @_allGeoVarsFlat() else new Map
    unbound = []
    for varName, varDef of @material.variable.input 
      scopeName = @_lookupAttrScope varName
      if scopeName
        bound.set varName, {scope: scopeName, type: varDef.type}
      else
        unbound.push varName
    {bound, unbound}
         
  _generateShader: ->
    @logger.info 'Generating shader'
    vcode = @material.vertexCode()
    fcode = @material.fragmentCode()
    @_shader = @_shaderBuilder.compute vcode, fcode

  _lookupAttrScope: (name) ->
    for scopeName of @geometry.scope
      if @geometry.scope[scopeName].data[name]?
        return scopeName
    return null

  _allGeoVarsFlat: ->
    attrScopeMap = new Map
    scopesFromMostGeneral = Object.keys(@geometry.scope).reverse()
    for scopeName in scopesFromMostGeneral
      for attrName, attr of @geometry.scope[scopeName].data
        attrScopeMap.set attrName, {scope: scopeName, type: attr.type}
    attrScopeMap

  update: ->
    @_bindVariables()

export create = (args...) -> new Mesh args...



###############
### GPUMesh ###
###############

export class GPUMesh extends Lazy.LazyManager
  constructor: (@_gl, attributeRegistry, mesh) ->
    super
      label       : "GPU.#{mesh.label}"
      lazyManager : new Lazy.HierarchicalManager 
    @_attributeRegistry = attributeRegistry
    @mesh               = mesh
    @_varLoc            = {}
    @buffer             = {}
    @_program           = null
    mesh.dirty.onSet.addEventListener => @dirty.setElem mesh
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
      @mesh.variables.bound.forEach (cfg, varName) =>
        @_initSpaceVarLocation cfg.scope, varName
      for varName in @mesh.variables.unbound
        @_initSpaceVarLocation 'object', varName

  _initSpaceVarLocation: (scopeName, varName) ->
      if scopeName == 'object'
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
      @mesh.variables.bound.forEach (cfg, varName) =>
        @bindAttrToProgram cfg.scope, varName
      
  _bindAttrToProgram: (scopeName, varName) -> 
    GL.withVAO @_gl, @_vao, =>  
      @bindAttrToProgram scopeName, varName

  bindAttrToProgram: (scopeName, varName) -> 
    if scopeName != 'object'
      @logger.group "Binding variable '#{scopeName}.#{varName}'", =>
        space = @mesh.geometry[scopeName].data
        val   = space[varName]
        loc   = @_varLoc[varName]
        if not @buffer[scopeName]?
          @buffer[scopeName] = {}
        if loc != undefined
          @_attributeRegistry.bindBuffer @, val, (bufferx) =>
            buffer    = bufferx._buffer
            instanced = (scopeName == 'instance')
            @buffer[scopeName][varName] = buffer 
            bufferx.bindToLoc loc, instanced 
            @logger.info "Variable bound succesfully using 
                         #{bufferx.chunksNum} locations"


  update: ->
    @logger.group "Update", =>
      oldShader = @mesh.shader
      @mesh.update()
      newShader = @mesh.shader
      if oldShader == newShader
        @logger.info "Shader did not change"
      else
        @_init()


  draw: (camera) ->
    @logger.group "Drawing", =>
      @_gl.useProgram @_program.glProgram      
      GL.withVAO @_gl, @_vao, =>
        texID = 0
        data  = @mesh.geometry.object.data
        vars  = Object.assign {}, data
        if camera?
          vars = Object.assign vars, camera.variables
        for key, val of vars
          glType = val.glType
          glVal  = val.glValue @_gl
          if val.type == texture.type
            @_gl.activeTexture (@_gl.TEXTURE0 + texID)
            @_gl.bindTexture @_gl.TEXTURE_2D, glVal
            glVal = texID
            texID += 1
          val.gl.uniSetter @_gl, @_varLoc[key], glVal

        pointCount    = @mesh.geometry.point.length
        instanceCount = @mesh.geometry.instance.length
        isInstanced   = not _.isEmpty(@mesh.geometry.instance.data)
        if isInstanced
          instanceWord = if instanceCount == 1 then "instance" else "instances"
          @logger.info "Drawing #{instanceCount} " + instanceWord
          if instanceCount != 0
            # @_gl.drawBuffers([
            #   @_gl.COLOR_ATTACHMENT0,
            #   @_gl.COLOR_ATTACHMENT1 
            # ]) # FIXME: remove
            @_gl.drawArraysInstanced @_gl.TRIANGLE_STRIP, 0, pointCount, 
                                     instanceCount
        else 
          @logger.info "Drawing not instanced geometry"
          @_gl.drawArrays @_gl.TRIANGLE_STRIP, 0, pointCount
          


#######################
### GPUMeshRegistry ###
#######################

export class GPUMeshRegistry extends Lazy.LazyManager
  constructor: (@_gl) ->
    super
      lazyManager : new Lazy.HierarchicalManager    
    @_meshes            = new Set

  add: (gpuMesh) ->
    @_meshes.add gpuMesh
    gpuMesh.dirty.onSet.addEventListener =>
      @dirty.setElem gpuMesh

  forEach: (f) ->
    for gpuMesh from @_meshes
      f gpuMesh

  update: ->
    if @dirty.isSet
      @logger.group "Updating", =>
        @dirty.elems.forEach (gpuMesh) =>
          gpuMesh.update()
        @logger.group "Unsetting dirty flags", =>
          @dirty.unset()
    else @logger.info "Everything up to date"