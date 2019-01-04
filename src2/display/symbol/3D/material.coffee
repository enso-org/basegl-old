import * as Lazy     from 'basegl/object/lazy'
import * as Property from 'basegl/object/Property'
import {vec4} from 'basegl/data/vector'


###################
### GLSLBuilder ###
###################

export class GLSLBuilder
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
  addDefinition     : (t, n, v) -> 
    if v? 
      @addAssignment "#{t} #{n}", v
    else
      @addExpr "#{t} #{n}"
  addInput          : (args...) -> @addAttr 'in'      , args...
  addOutput         : (args...) -> @addAttr 'out'     , args...
  addUniform        : (args...) -> @addAttr 'uniform' , args...
  addAttr           : (qual,type,name,cfg) -> # (qual, prec, type, name) ->
    l = if cfg.loc?  then "layout(location=#{cfg.loc}) " else ""
    p = if cfg.prec? then " #{cfg.prec} " else " "
    @addExpr "#{l}#{qual}#{p}#{type} #{name}"
  buildMain     : (f) ->
    @addLine 'void main() {'
    f?()
    @addLine '}'

  

#######################
### ShaderPrecision ###
#######################

glsl =
  precision:
    low:    'lowp'
    medium: 'mediump'
    high:   'highp'
      
export class ShaderPrecision
  constructor: ->
    @float                = glsl.precision.medium
    @int                  = glsl.precision.medium
    @sampler2D            = glsl.precision.low 
    @samplerCube          = glsl.precision.low 
    @sampler3D            = glsl.precision.low   
    @samplerCubeShadow    = glsl.precision.low         
    @sampler2DShadow      = glsl.precision.low       
    @sampler2DArray       = glsl.precision.low      
    @sampler2DArrayShadow = glsl.precision.low            
    @isampler2D           = glsl.precision.low  
    @isampler3D           = glsl.precision.low  
    @isamplerCube         = glsl.precision.low    
    @isampler2DArray      = glsl.precision.low       
    @usampler2D           = glsl.precision.low  
    @usampler3D           = glsl.precision.low  
    @usamplerCube         = glsl.precision.low    
    @usampler2DArray      = glsl.precision.low 



#####################
### ShaderBuilder ###
#####################

export class ShaderBuilder
  constructor: (@material) ->
    @resetVariables()
    @resetPrecision()
    
  resetVariables: ->
    @constants  = {}
    @attributes = {}
    @locals     = {}
    @uniforms   = {}
    @outputs    = {}

    @fragment          = new GLSLBuilder
    @fragmentBody      = new GLSLBuilder false
    @fragmentAfterBody = new GLSLBuilder false

    @vertex            = new GLSLBuilder
    @vertexBody        = new GLSLBuilder false
    @vertexAfterBody   = new GLSLBuilder false

  resetPrecision: ->
    @precision =
      vertex   : new ShaderPrecision
      fragment : new ShaderPrecision
    @precision.vertex.float = glsl.precision.high
    @precision.vertex.int   = glsl.precision.high

  mkVertexName:   (s) -> 'v_' + s
  mkFragmentName: (s) -> s
  mkOutputName:   (s) -> 'output_' + s

  readVar: (name,cfg) ->
    type = cfg
    prec = null
    if cfg.constructor == Object
      type = cfg.type
      prec = cfg.precision
    {name, type, prec}

  compute: (providedVertexCode, providedFragmentCode) ->
    addSection = (s) =>
      @vertex.addSection s
      @fragment.addSection s
      
    addSection 'Default precision declarations'
    for type, prec of @precision.vertex
      @vertex.addExpr "precision #{prec} #{type}"
    for type, prec of @precision.fragment
      @fragment.addExpr "precision #{prec} #{type}"

    if @constants
      addSection 'Constants'
      for name,cfg of @constants
        @vertex.addDefinition   cfg.type, name , cfg.value
        @fragment.addDefinition cfg.type, name , cfg.value

    if @attributes
      addSection 'Attributes shared between vertex and fragment shaders'
      for name,cfg of @attributes
        v = @readVar name, cfg
        fragmentName = @mkFragmentName v.name
        vertexName   = @mkVertexName   v.name
        @vertex.addInput   v.type, vertexName  , {prec: v.prec}
        @vertex.addOutput  v.type, fragmentName, {prec: v.prec}
        @fragment.addInput v.type, fragmentName, {prec: v.prec}
        @vertexBody.addAssignment fragmentName, vertexName

    if @locals
      addSection 'Local variables shared between vertex and fragment shaders'
      for name,cfg of @locals
        v = @readVar name, cfg
        fragmentName = @mkFragmentName v.name
        vertexName   = @mkVertexName   v.name
        @vertex.addOutput  v.type, fragmentName, {prec: v.prec}
        @fragment.addInput v.type, fragmentName, {prec: v.prec}
    
    if @uniforms
      addSection 'Uniforms'
      for name,cfg of @uniforms
        v = @readVar name, cfg       
        prec = 'mediump' # FIXME! Hardcoded because we cannot get mismatch of prec between vertex and fragment shader!
        @vertex.addUniform   v.type, v.name, {prec}
        @fragment.addUniform v.type, v.name, {prec}

    if @outputs
      @fragment.addSection 'Outputs'
      loc = 0    
      for name,cfg of @outputs
        v    = @readVar name, cfg 
        name = @mkOutputName v.name
        prec = v.prec       
        @fragment.addOutput v.type, name, {prec, loc}
        loc += 1

    
    ### Generating vertex code ###

    handleMain = (providedCode, tgt, tgtBody, tgtAferBody) =>
    
      part = partitionGLSL providedCode
  
      tgtBody.addSection "Main entry point"
      if part.left
        logger.error "Error while generating vertex shader, reverting to default"
        logger.error part.left
      else
        val = part.right
        tgt.addSection "Material code"
        tgt.addLine val.before
        tgtBody.addCommentSection "Material main code"
        tgtBody.addLine val.body
        if val.after.length > 0
          tgtAferBody.addSection "Material code"      
          tgtAferBody.addLine val.after
  
      


    handleMain providedVertexCode, @vertex, @vertexBody, @vertexAfterBody
    handleMain providedFragmentCode, @fragment, @fragmentBody, @fragmentAfterBody


  @getter 'code', ->
    assemble = (tgt, tgtBody, tgtAferBody) =>
      tgt.buildMain =>
        tgt.addText tgtBody.code
        tgt.addText tgtAferBody.code

    assemble @vertex, @vertexBody, @vertexAfterBody
    assemble @fragment, @fragmentBody, @fragmentAfterBody

    return
      vertex   : @vertex.code
      fragment : @fragment.code
    


#############################
### GLSL Processing Utils ###
#############################


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



################
### Material ###
################

export class Material extends Lazy.LazyManager
  constructor: (cfg={}) -> 
    super cfg 
    @_variable = 
      input  : cfg.input  || {}
      locals : cfg.locals || {}
      output : Object.assign {color: vec4}, (cfg.output || {})
  @getter 'variable', -> @_variable

  generate     : (shaderBuilder) ->
  vertexCode   : -> ''
  fragmentCode : -> ''
  


####################
### Raw Material ###
####################

defaultRawVertexShader = '''
void main() {
  gl_Position = vec4(position,1.0);
}
'''

defaultRawFragmentShader= '''
void main() {
  output_color = vec4(1.0,0.0,0.0,1.0);
}
'''

export class Raw extends Material
  constructor: (cfg={}) ->
    super cfg
    @_vertex   = cfg.vertex   || defaultRawVertexShader
    @_fragment = cfg.fragment || defaultRawFragmentShader
  @getter 'vertex'   ,     -> @_vertex
  @getter 'fragment' ,     -> @_fragment
  @setter 'vertex'   , (v) -> @_vertex   = v; @dirty.set()
  @setter 'fragment' , (v) -> @_fragment = v; @dirty.set()

  vertexCode:   -> @vertex
  fragmentCode: -> @fragment





export class Proxy 
  @generateAccessors()

  constructor: (@_material, @_targetOutputs) ->
    outputs = {}
    # console.log "---"
    # console.log @material.variable.output
    # console.log @targetOutputs
    for name,output of @targetOutputs
      outputs['proxy_' + name] = output.type

    @_variable = 
      input  : @material.variable.input
      locals : @material.variable.locals
      output : outputs
  
  @getter 'dirty'    , -> @material.dirty
  @getter 'vertex'   , -> @material.vertex
  @getter 'fragment' , -> @material.fragment

  vertexCode:   -> @vertex
  fragmentCode: -> @fragment
  generate: (shaderBuilder) ->
    # console.log @targetOutputs
    fragment     = shaderBuilder.fragment
    fragmentBody = shaderBuilder.fragmentBody
    for name,output of @material.variable.output
      glType = output.type.gl.name   
      outputName      = 'output_' + name 
      outputProxyName = 'output_proxy_' + name
      fragment.addDefinition glType, outputName
      fragmentBody.addExpr "convert(#{outputProxyName}, #{outputName})"
 