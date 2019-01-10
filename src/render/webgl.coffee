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
  loadVertexShader   : (code)   -> @loadShader 'vertex'   , @_gl.VERTEX_SHADER   , code 
  loadFragmentShader : (code)   -> @loadShader 'fragment' , @_gl.FRAGMENT_SHADER , code 
  loadShader: (name, type, code) ->
    shader = loadShader @_gl, name, code, type
    @attachShader shader

shaderErrorNumber = 0

export loadShader = (gl, name, shaderSource, shaderType) ->
  shader = gl.createShader shaderType
  gl.shaderSource shader, shaderSource
  gl.compileShader shader
  compiled = gl.getShaderParameter shader, gl.COMPILE_STATUS
  if not compiled
    lastError = gl.getShaderInfoLog shader
    console.error ("*** Error compiling #{name} shader:\n" + lastError)
    logfname = "printShaderError#{shaderErrorNumber}"
    console.error "Use '#{logfname}' to see its source"
    window[logfname] = ->
      console.error(shaderSource)
    shaderErrorNumber += 1

    listCode shaderSource
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



digitsCount = (number) ->
  Math.floor(Math.log10(number)) + 1

listCode = (code) -> 
  lines     = code.split(/\r?\n/)
  maxDigits = digitsCount lines.length
  
  listLines  = []
  lineNumber = 0
  for line in lines
    lineNumber += 1
    digits      = digitsCount lineNumber
    spaces      = maxDigits - digits
    linePfx     = " ".repeat(spaces) + "#{lineNumber}: "
    listLine    = linePfx + line
    listLines.push listLine

  listing = listLines.join '\n'
  listing