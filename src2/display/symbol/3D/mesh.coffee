import * as GL          from 'basegl/lib/webgl/utils'
import * as Lazy        from 'basegl/object/lazy'
import * as Material    from 'basegl/display/symbol/3D/material'
import {shallowCompare} from 'basegl/object/compare'
import {Program}        from 'basegl/render/webgl'
import * as _           from 'lodash'

############
### Mesh ###
############

export class Mesh extends Lazy.LazyManager
  constructor: (geometry, material) ->
    super
      label       : "Mesh." + geometry.label
      lazyManager : new Lazy.HierarchicalManager 
    @_geometry      = geometry
    @_material      = material
    @_shader        = null
    @_bindings      = {}
    @_shaderBuilder = new Material.ShaderBuilder 
    @geometry.dirty.onSet.addEventListener => @dirty.setElem @geometry
    @material.dirty.onSet.addEventListener => @dirty.setElem @material
    @_bindVariables()

  @getter 'geometry' , -> @_geometry
  @getter 'material' , -> @_material
  @getter 'shader'   , -> @_shader
  @getter 'bindings' , -> @_bindings

  _bindVariables: ->
    {bindings, missing} = @_matchVariables()
    bindingsChanged     = not shallowCompare @bindings, bindings
    materialChanged     = @material.dirty.isSet
    if bindingsChanged || materialChanged
      @logger.group "Binding variables", =>
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

export create = (args...) -> new Mesh args...



###############
### GPUMesh ###
###############

export class GPUMesh extends Lazy.LazyManager
  constructor: (@_gl, bufferRegistry, mesh) ->
    super
      label       : "GPU.#{mesh.label}"
      lazyManager : new Lazy.HierarchicalManager 
    @_bufferRegistry = bufferRegistry
    @mesh            = mesh
    @_varLoc         = {}
    @buffer          = {}
    @_program        = null
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

  # _unsetDirtyChildren: ->
  #   @mesh.dirty.unset()

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
        isInstanced   = not _.isEmpty(@mesh.geometry.instance.data)
        if isInstanced
          instanceWord = if instanceCount == 1 then "instance" else "instances"
          @logger.info "Drawing #{instanceCount} " + instanceWord
          if instanceCount != 0
            @_gl.drawArraysInstanced(@_gl.TRIANGLE_STRIP, 0, pointCount, instanceCount)
        else 
          @logger.info "Drawing not instanced geometry"
          @_gl.drawArrays(@_gl.TRIANGLE_STRIP, 0, pointCount)
          


#######################
### GPUMeshRegistry ###
#######################

export class GPUMeshRegistry extends Lazy.LazyManager
  constructor: ->
    super
      lazyManager : new Lazy.HierarchicalManager    
    @_meshes = new Set

  # @getter 'dirtyMeshes', -> @_dirty.elems

  add: (mesh) ->
    @_meshes.add mesh
    mesh.dirty.onSet.addEventListener =>
      @dirty.setElem mesh

  update: ->
    if @dirty.isSet
      @logger.group "Updating", =>
        @dirty.elems.forEach (mesh) =>
          mesh.update()
        @logger.group "Unsetting dirty flags", =>
          @dirty.unset()
    else @logger.info "Everything up to date"