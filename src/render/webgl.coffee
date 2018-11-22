import * as Property from "basegl/object/Property"

  
  
export class Program 
  constructor: (@_gl) ->
    @_glProgram = @_gl.createProgram()
  @getter 'glProgram', -> @_glProgram

  @from: (gl, vertexCode, fragmentCode) ->
    program = new Program gl
    program.loadVertexShader   vertexCode
    program.loadFragmentShader fragmentCode
    error = program.link()
    if error
      console.error ("Error in program linking:" + erro)
      Program.delete()
      return null
    program

  link: -> 
    @_gl.linkProgram @_glProgram
    linked = @_gl.getProgramParameter @_glProgram, @_gl.LINK_STATUS
    if not linked
      lastError = gl.getProgramInfoLog @_glprogram
      return lastError
    return null

  delete: -> @_gl.deleteProgram @_glProgram
  attachShader       : (shader) -> @_gl.attachShader @_glProgram, shader
  getAttribLocation  : (attr)   -> @_gl.getAttribLocation  @_glProgram, attr
  getUniformLocation : (attr)   -> @_gl.getUniformLocation @_glProgram, attr
  loadVertexShader   : (code)   -> @loadShader @_gl.VERTEX_SHADER   , code 
  loadFragmentShader : (code)   -> @loadShader @_gl.FRAGMENT_SHADER , code 
  loadShader: (type, code) ->
    shader = loadShader @_gl, code, type
    @attachShader shader

export loadShader = (gl, shaderSource, shaderType) ->
  shader = gl.createShader shaderType
  gl.shaderSource shader, shaderSource
  gl.compileShader shader
  compiled = gl.getShaderParameter shader, gl.COMPILE_STATUS
  if not compiled
    lastError = gl.getShaderInfoLog shader
    console.error ("*** Error compiling shader '" + shader + "':" + lastError)
    gl.deleteShadershader
    return null
  return shader

export resizeCanvasToDisplaySize = (canvas, multiplier) ->
  multiplier = multiplier || 1
  width  = canvas.clientWidth  * multiplier | 0
  height = canvas.clientHeight * multiplier | 0
  if (canvas.width != width ||  canvas.height != height)
    canvas.width  = width
    canvas.height = height
    true
  false
