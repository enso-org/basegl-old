
  
  
error = console.error


# Loads a shader.
# @param {WebGLRenderingContext} gl The WebGLRenderingContext to use.
# @param {string} shaderSource The shader source.
# @param {number} shaderType The type of shader.
# @param {module:webgl-utils.ErrorCallback} opt_errorCallback callback for errors.
# @return {WebGLShader} The created shader.
export loadShader = (gl, shaderSource, shaderType, opt_errorCallback) ->
  errFn = opt_errorCallback || error
  shader = gl.createShader(shaderType)
  gl.shaderSource(shader, shaderSource)

  # Compile the shader
  gl.compileShader(shader)

  # Check the compile status
  compiled = gl.getShaderParameter(shader, gl.COMPILE_STATUS)
  if (!compiled) 
    # Something went wrong during compilation get the error
    lastError = gl.getShaderInfoLog(shader)
    errFn("*** Error compiling shader '" + shader + "':" + lastError)
    gl.deleteShader(shader)
    return null
  

  return shader


class Program 
  constructor: (@context, @glProgram) ->

  getAttribLocation:  (a) -> @context.getAttribLocation  @glProgram, a
  getUniformLocation: (a) -> @context.getUniformLocation @glProgram, a

  lookupVariables: (vars) ->
    out =
      attribute : {}
      uniform   : {}

    for a of vars.attribute
      out.attribute[a] = @getAttribLocation a
    
    for a of vars.uniform
      out.uniform[a] = @getUniformLocation a
    
    out

# Creates a program, attaches shaders, binds attrib locations, links the
# program and calls useProgram.
# @param {WebGLShader[]} shaders The shaders to attach
# @param {string[]} [opt_attribs] An array of attribs names. Locations will be assigned by index if not passed in
# @param {number[]} [opt_locations] The locations for the. A parallel array to opt_attribs letting you assign locations.
# @param {module:webgl-utils.ErrorCallback} opt_errorCallback callback for errors. By default it just prints an error to the console
#        on error. If you want something else pass an callback. It's passed an error message.
# @memberOf module:webgl-utils
export createProgram = (ctx, shaders, opt_attribs, opt_locations, opt_errorCallback) ->
  errFn   = opt_errorCallback || error
  program = ctx.createProgram()
  shaders.forEach (shader) ->
    ctx.attachShader(program, shader)
  if opt_attribs
    opt_attribs.forEach (attrib, ndx) ->
      ctx.bindAttribLocation(
          program,
          if opt_locations then opt_locations[ndx] else ndx,
          attrib)
  ctx.linkProgram(program)

  # Check the link status
  linked = ctx.getProgramParameter(program, ctx.LINK_STATUS)
  if (!linked)
      # something went wrong with the link
      lastError = ctx.getProgramInfoLog(program)
      errFn("Error in program linking:" + lastError)

      ctx.deleteProgram(program)
      return null
  new Program ctx, program

# /**
#   * Loads a shader from a script tag.
#   * @param {WebGLRenderingContext} gl The WebGLRenderingContext to use.
#   * @param {string} scriptId The id of the script tag.
#   * @param {number} opt_shaderType The type of shader. If not passed in it will
#   *     be derived from the type of the script tag.
#   * @param {module:webgl-utils.ErrorCallback} opt_errorCallback callback for errors.
#   * @return {WebGLShader} The created shader.
#   */
# function createShaderFromScript(
#     gl, scriptId, opt_shaderType, opt_errorCallback) {
#   shaderSource = ""
#   shaderType
#   shaderScript = document.getElementById(scriptId)
#   if (!shaderScript) {
#     throw ("*** Error: unknown script element" + scriptId)
#   }
#   shaderSource = shaderScript.text

#   if (!opt_shaderType) {
#     if (shaderScript.type === "x-shader/x-vertex") {
#       shaderType = gl.VERTEX_SHADER
#     } else if (shaderScript.type === "x-shader/x-fragment") {
#       shaderType = gl.FRAGMENT_SHADER
#     } else if (shaderType !== gl.VERTEX_SHADER && shaderType !== gl.FRAGMENT_SHADER) {
#       throw ("*** Error: unknown shader type")
#     }
#   }

#   return loadShader(
#       gl, shaderSource, opt_shaderType ? opt_shaderType : shaderType,
#       opt_errorCallback)
# }

defaultShaderType = [
  "VERTEX_SHADER",
  "FRAGMENT_SHADER",
]

# /**
#   * Creates a program from 2 script tags.
#   *
#   * @param {WebGLRenderingContext} gl The WebGLRenderingContext
#   *        to use.
#   * @param {string[]} shaderScriptIds Array of ids of the script
#   *        tags for the shaders. The first is assumed to be the
#   *        vertex shader, the second the fragment shader.
#   * @param {string[]} [opt_attribs] An array of attribs names. Locations will be assigned by index if not passed in
#   * @param {number[]} [opt_locations] The locations for the. A parallel array to opt_attribs letting you assign locations.
#   * @param {module:webgl-utils.ErrorCallback} opt_errorCallback callback for errors. By default it just prints an error to the console
#   *        on error. If you want something else pass an callback. It's passed an error message.
#   * @return {WebGLProgram} The created program.
#   * @memberOf module:webgl-utils
#   */
# function createProgramFromScripts(
#     gl, shaderScriptIds, opt_attribs, opt_locations, opt_errorCallback) {
#   shaders = []
#   for (ii = 0 ii < shaderScriptIds.length ++ii) {
#     shaders.push(createShaderFromScript(
#         gl, shaderScriptIds[ii], gl[defaultShaderType[ii]], opt_errorCallback))
#   }
#   return createProgram(gl, shaders, opt_attribs, opt_locations, opt_errorCallback)
# }

# # Creates a program from 2 sources.
# #
# # @param {WebGLRenderingContext} gl The WebGLRenderingContext
# #        to use.
# # @param {string[]} shaderSourcess Array of sources for the
# #        shaders. The first is assumed to be the vertex shader,
# #        the second the fragment shader.
# # @param {string[]} [opt_attribs] An array of attribs names. Locations will be assigned by index if not passed in
# # @param {number[]} [opt_locations] The locations for the. A parallel array to opt_attribs letting you assign locations.
# # @param {module:webgl-utils.ErrorCallback} opt_errorCallback callback for errors. By default it just prints an error to the console
# #        on error. If you want something else pass an callback. It's passed an error message.
# # @return {WebGLProgram} The created program.
# # @memberOf module:webgl-utils
export createProgramFromSources = (gl, shaderSources, opt_attribs, opt_locations, opt_errorCallback) ->
  shaders = []
  for ii in [0 ... shaderSources.length]
    shaders.push(loadShader(
        gl, shaderSources[ii], gl[defaultShaderType[ii]], opt_errorCallback))
  
  createProgram(gl, shaders, opt_attribs, opt_locations, opt_errorCallback)


# Resize a canvas to match the size its displayed.
# @param {HTMLCanvasElement} canvas The canvas to resize.
# @param {number} [multiplier] amount to multiply by.
#    Pass in window.devicePixelRatio for native pixels.
# @return {boolean} true if the canvas was resized.
# @memberOf module:webgl-utils
export resizeCanvasToDisplaySize = (canvas, multiplier) ->
  multiplier = multiplier || 1
  width  = canvas.clientWidth  * multiplier | 0
  height = canvas.clientHeight * multiplier | 0
  if (canvas.width != width ||  canvas.height != height)
    canvas.width  = width
    canvas.height = height
    true
  false

# return {
#   createProgram: createProgram,
#   createProgramFromScripts: createProgramFromScripts,
#   createProgramFromSources: createProgramFromSources,
#   resizeCanvasToDisplaySize: resizeCanvasToDisplaySize,
# }
  
  