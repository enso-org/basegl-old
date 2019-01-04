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
  addDefinition     : (t, n, v) -> @addAssignment "#{t} #{n}", v
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
        vertexCode.addDefinition   cfg.type, name , cfg.value
        fragmentCode.addDefinition cfg.type, name , cfg.value

    if @attributes
      addSection 'Attributes shared between vertex and fragment shaders'
      for name,cfg of @attributes
        v = @readVar name, cfg
        fragmentName = @mkFragmentName v.name
        vertexName   = @mkVertexName   v.name
        vertexCode.addInput   v.type, vertexName  , {prec: v.prec}
        vertexCode.addOutput  v.type, fragmentName, {prec: v.prec}
        fragmentCode.addInput v.type, fragmentName, {prec: v.prec}
        vertexBodyCode.addAssignment fragmentName, vertexName

    if @locals
      addSection 'Local variables shared between vertex and fragment shaders'
      for name,cfg of @locals
        v = @readVar name, cfg
        fragmentName = @mkFragmentName v.name
        vertexName   = @mkVertexName   v.name
        vertexCode.addOutput  v.type, fragmentName, {prec: v.prec}
        fragmentCode.addInput v.type, fragmentName, {prec: v.prec}
    
    if @uniforms
      addSection 'Uniforms'
      for name,cfg of @uniforms
        v = @readVar name, cfg       
        prec = 'mediump' # FIXME! We cannot get mismatch of prec between vertex and fragment shader!
        vertexCode.addUniform   v.type, v.name, {prec}
        fragmentCode.addUniform v.type, v.name, {prec}

    if @outputs
      fragmentCode.addSection 'Outputs'
      loc = 0    
      for name,cfg of @outputs
        v    = @readVar name, cfg 
        name = @mkOutputName v.name
        prec = v.prec       
        fragmentCode.addOutput v.type, name, {prec, loc}
        loc += 1

    
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

    # console.warn providedFragmentCode
    
    return
      vertex   : vertexCode.code
      fragment : fragmentCode.code
    


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

  constructor: (@_material) ->
    @_variable = 
      input  : @material.variable.input
      locals : Object.assign {foo: vec4}, @material.variable.locals
      output : {}
  
  @getter 'dirty'    , -> @material.dirty
  @getter 'vertex'   , -> @material.vertex
  @getter 'fragment' , -> @material.fragment

  vertexCode:   -> @vertex
  fragmentCode: -> @fragment
