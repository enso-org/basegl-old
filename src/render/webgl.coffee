import * as Property from "basegl/object/Property"

  
  
class Program 
  constructor: (@_ctx, @_glProgram) ->
  @getter 'glProgram', -> @_glProgram

  getAttribLocation:  (a) -> @_ctx.getAttribLocation  @_glProgram, a
  getUniformLocation: (a) -> @_ctx.getUniformLocation @_glProgram, a


export loadShader = (gl, shaderSource, shaderType) ->
  shader = gl.createShader shaderType
  gl.shaderSource shader, shaderSource
  gl.compileShader(shader)
  compiled = gl.getShaderParameter shader, gl.COMPILE_STATUS
  if (!compiled) 
    lastError = gl.getShaderInfoLog(shader)
    console.error ("*** Error compiling shader '" + shader + "':" + lastError)
    gl.deleteShader(shader)
    return null
  return shader




export createProgram = (ctx, shaders) ->
  program = ctx.createProgram()
  shaders.forEach (shader) ->
    ctx.attachShader(program, shader)

  ctx.linkProgram(program)
  linked = ctx.getProgramParameter(program, ctx.LINK_STATUS)
  if (!linked)
      lastError = ctx.getProgramInfoLog(program)
      console.error ("Error in program linking:" + lastError)
      ctx.deleteProgram(program)
      return null
  new Program ctx, program

export createProgramFromSources = (gl, vertexCode, fragmentCode) ->
  vertexShader   = loadShader gl , vertexCode   , gl.VERTEX_SHADER
  fragmentShader = loadShader gl , fragmentCode , gl.FRAGMENT_SHADER
  
  createProgram(gl, [vertexShader, fragmentShader])


export resizeCanvasToDisplaySize = (canvas, multiplier) ->
  multiplier = multiplier || 1
  width  = canvas.clientWidth  * multiplier | 0
  height = canvas.clientHeight * multiplier | 0
  if (canvas.width != width ||  canvas.height != height)
    canvas.width  = width
    canvas.height = height
    true
  false
