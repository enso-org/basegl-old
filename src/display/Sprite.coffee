import * as Config   from 'basegl/object/config'
import * as Variable from 'basegl/display/symbol/3D/geometry/variable'
import * as Geometry from 'basegl/display/symbol/3D/geometry'
import * as Material from 'basegl/display/symbol/3D/material'
import * as Mesh     from 'basegl/display/symbol/3D/mesh'
import * as Lazy     from 'basegl/object/lazy'
import * as Property from 'basegl/object/Property'
import * as EventDispatcher from 'basegl/event/dispatcher'
import * as Buffer   from 'basegl/data/buffer'

import {singleShotEventDispatcher} from 'basegl/event/dispatcher'

import {logger}                             from 'logger'
import {vec2, vec3, vec4, mat2, mat3, mat4, Vec3, float, texture} from 'basegl/data/vector'
import * as _ from 'lodash'

import * as M from 'gl-matrix'


import * as Display from 'basegl/display/object'


import {EventObject} from 'basegl/display/object/event'
import {DisplayObject} from 'basegl/display/object'
import {Logged} from 'basegl/object/logged'


import vertexHeader   from 'basegl/lib/shader/component/vertexHeader'
import vertexBody     from 'basegl/lib/shader/component/vertexBody'
import fragmentHeader from 'basegl/lib/shader/component/fragmentHeader'
import fragmentRunner from 'basegl/lib/shader/component/fragmentRunner'
import fragment_lib   from 'basegl/lib/shader/sdf/sdf'



builtins = '''
float radians(float degrees)  
vec2 radians(vec2 degrees)  
vec3 radians(vec3 degrees)  
vec4 radians(vec4 degrees)
float degrees(float radians)  
vec2 degrees(vec2 radians)  
vec3 degrees(vec3 radians)  
vec4 degrees(vec4 radians)
float sin(float angle)  
vec2 sin(vec2 angle)  
vec3 sin(vec3 angle)  
vec4 sin(vec4 angle)
float cos(float angle)  
vec2 cos(vec2 angle)  
vec3 cos(vec3 angle)  
vec4 cos(vec4 angle)
float tan(float angle)  
vec2 tan(vec2 angle)  
vec3 tan(vec3 angle)  
vec4 tan(vec4 angle)
float asin(float x)  
vec2 asin(vec2 x)  
vec3 asin(vec3 x)  
vec4 asin(vec4 x)
float acos(float x)  
vec2 acos(vec2 x)  
vec3 acos(vec3 x)  
vec4 acos(vec4 x)
float pow(float x, float y)  
vec2 pow(vec2 x, vec2 y)  
vec3 pow(vec3 x, vec3 y)  
vec4 pow(vec4 x, vec4 y)
float exp(float x)  
vec2 exp(vec2 x)  
vec3 exp(vec3 x)  
vec4 exp(vec4 x)
float log(float x)  
vec2 log(vec2 x)  
vec3 log(vec3 x)  
vec4 log(vec4 x)
float exp2(float x)  
vec2 exp2(vec2 x)  
vec3 exp2(vec3 x)  
vec4 exp2(vec4 x)
float log2(float x)  
vec2 log2(vec2 x)  
vec3 log2(vec3 x)  
vec4 log2(vec4 x)
float sqrt(float x)  
vec2 sqrt(vec2 x)  
vec3 sqrt(vec3 x)  
vec4 sqrt(vec4 x)
float inversesqrt(float x)  
vec2 inversesqrt(vec2 x)  
vec3 inversesqrt(vec3 x)  
vec4 inversesqrt(vec4 x)
float abs(float x)  
vec2 abs(vec2 x)  
vec3 abs(vec3 x)  
vec4 abs(vec4 x)
float sign(float x)  
vec2 sign(vec2 x)  
vec3 sign(vec3 x)  
vec4 sign(vec4 x)
float floor(float x)  
vec2 floor(vec2 x)  
vec3 floor(vec3 x)  
vec4 floor(vec4 x)
float ceil(float x)  
vec2 ceil(vec2 x)  
vec3 ceil(vec3 x)  
vec4 ceil(vec4 x)
float fract(float x)  
vec2 fract(vec2 x)  
vec3 fract(vec3 x)  
vec4 fract(vec4 x)
float mod(float x, float y)  
vec2 mod(vec2 x, vec2 y)  
vec3 mod(vec3 x, vec3 y)  
vec4 mod(vec4 x, vec4 y)
vec2 mod(vec2 x, float y)  
vec3 mod(vec3 x, float y)  
vec4 mod(vec4 x, float y)
float min(float x, float y)  
vec2 min(vec2 x, vec2 y)  
vec3 min(vec3 x, vec3 y)  
vec4 min(vec4 x, vec4 y)
vec2 min(vec2 x, float y)  
vec3 min(vec3 x, float y)  
vec4 min(vec4 x, float y)
vec2 max(vec2 x, vec2 y)  
vec3 max(vec3 x, vec3 y)  
vec4 max(vec4 x, vec4 y)
float max(float x, float y)  
vec2 max(vec2 x, float y)  
vec3 max(vec3 x, float y)  
vec4 max(vec4 x, float y)
vec2 clamp(vec2 x, vec2 minVal, vec2 maxVal)  
vec3 clamp(vec3 x, vec3 minVal, vec3 maxVal)  
vec4 clamp(vec4 x, vec4 minVal, vec4 maxVal)
float clamp(float x, float minVal, float maxVal)  
vec2 clamp(vec2 x, float minVal, float maxVal)  
vec3 clamp(vec3 x, float minVal, float maxVal)  
vec4 clamp(vec4 x, float minVal, float maxVal) 
vec2 mix(vec2 x, vec2 y, vec2 a)  
vec3 mix(vec3 x, vec3 y, vec3 a)  
vec4 mix(vec4 x, vec4 y, vec4 a)
float mix(float x, float y, float a)  
vec2 mix(vec2 x, vec2 y, float a)  
vec3 mix(vec3 x, vec3 y, float a)  
vec4 mix(vec4 x, vec4 y, float a)
vec2 step(vec2 edge, vec2 x)  
vec3 step(vec3 edge, vec3 x)  
vec4 step(vec4 edge, vec4 x)
float step(float edge, float x)  
vec2 step(float edge, vec2 x)  
vec3 step(float edge, vec3 x)  
vec4 step(float edge, vec4 x)
float smoothstep(float edge0, float edge1, float x)  
vec2 smoothstep(vec2 edge0, vec2 edge1, vec2 x)  
vec3 smoothstep(vec3 edge0, vec3 edge1, vec3 x)  
vec4 smoothstep(vec4 edge0, vec4 edge1, vec4 x)
vec2 smoothstep(float edge0, float edge1, vec2 x)  
vec3 smoothstep(float edge0, float edge1, vec3 x)  
vec4 smoothstep(float edge0, float edge1, vec4 x)
float length(float x)  
float length(vec2 x)  
float length(vec3 x)  
float length(vec4 x)
float distance(float p0, float p1)  
float distance(vec2 p0, vec2 p1)  
float distance(vec3 p0, vec3 p1)  
float distance(vec4 p0, vec4 p1)
float dot(float x, float y)  
float dot(vec2 x, vec2 y)  
float dot(vec3 x, vec3 y)  
float dot(vec4 x, vec4 y)
vec3 cross(vec3 x, vec3 y)
float normalize(float x)  
vec2 normalize(vec2 x)  
vec3 normalize(vec3 x)  
vec4 normalize(vec4 x)
float faceforward(float N, float I, float Nref)  
vec2 faceforward(vec2 N, vec2 I, vec2 Nref)  
vec3 faceforward(vec3 N, vec3 I, vec3 Nref)  
vec4 faceforward(vec4 N, vec4 I, vec4 Nref)
float reflect(float I, float N)  
vec2 reflect(vec2 I, vec2 N)  
vec3 reflect(vec3 I, vec3 N)  
vec4 reflect(vec4 I, vec4 N)
float refract(float I, float N, float eta)  
vec2 refract(vec2 I, vec2 N, float eta)  
vec3 refract(vec3 I, vec3 N, float eta)  
vec4 refract(vec4 I, vec4 N, float eta)
mat2 matrixCompMult(mat2 x, mat2 y)  
mat3 matrixCompMult(mat3 x, mat3 y)  
mat4 matrixCompMult(mat4 x, mat4 y)
bvec2 lessThan(vec2 x, vec2 y)  
bvec3 lessThan(vec3 x, vec3 y)    
bvec4 lessThan(vec4 x, vec4 y)  
bvec2 lessThan(ivec2 x, ivec2 y)  
bvec3 lessThan(ivec3 x, ivec3 y)  
bvec4 lessThan(ivec4 x, ivec4 y)
bvec2 lessThanEqual(vec2 x, vec2 y)  
bvec3 lessThanEqual(vec3 x, vec3 y)  
bvec4 lessThanEqual(vec4 x, vec4 y)  
bvec2 lessThanEqual(ivec2 x, ivec2 y)  
bvec3 lessThanEqual(ivec3 x, ivec3 y)  
bvec4 lessThanEqual(ivec4 x, ivec4 y)
bvec2 greaterThan(vec2 x, vec2 y)  
bvec3 greaterThan(vec3 x, vec3 y)  
bvec4 greaterThan(vec4 x, vec4 y)  
bvec2 greaterThan(ivec2 x, ivec2 y)  
bvec3 greaterThan(ivec3 x, ivec3 y)  
bvec4 greaterThan(ivec4 x, ivec4 y)
bvec2 greaterThanEqual(vec2 x, vec2 y)  
bvec3 greaterThanEqual(vec3 x, vec3 y)  
bvec4 greaterThanEqual(vec4 x, vec4 y)  
bvec2 greaterThanEqual(ivec2 x, ivec2 y)  
bvec3 greaterThanEqual(ivec3 x, ivec3 y)  
bvec4 greaterThanEqual(ivec4 x, ivec4 y)
bvec2 equal(vec2 x, vec2 y)  
bvec3 equal(vec3 x, vec3 y)  
bvec4 equal(vec4 x, vec4 y)  
bvec2 equal(ivec2 x, ivec2 y)  
bvec3 equal(ivec3 x, ivec3 y)  
bvec4 equal(ivec4 x, ivec4 y)
bvec2 notEqual(vec2 x, vec2 y)  
bvec3 notEqual(vec3 x, vec3 y)  
bvec4 notEqual(vec4 x, vec4 y)  
bvec2 notEqual(ivec2 x, ivec2 y)  
bvec3 notEqual(ivec3 x, ivec3 y)  
bvec4 notEqual(ivec4 x, ivec4 y)
bool any(bvec2 x)  
bool any(bvec3 x)  
bool any(bvec4 x)
bool all(bvec2 x)  
bool all(bvec3 x)  
bool all(bvec4 x)
bvec2 not(bvec2 x)  
bvec3 not(bvec3 x)  
bvec4 not(bvec4 x)
'''




# loadTexture = (gl, url) ->
#   texture = gl.createTexture()
#   gl.bindTexture(gl.TEXTURE_2D, texture)

#   level = 0
#   internalFormat = gl.RGBA
#   width = 1
#   height = 1
#   border = 0
#   srcFormat = gl.RGBA
#   srcType = gl.UNSIGNED_BYTE
#   pixel = new Uint8Array([0, 0, 255, 255])  
#   gl.texImage2D(gl.TEXTURE_2D, level, internalFormat,
#                 width, height, border, srcFormat, srcType,
#                 pixel)

#   image = new Image()
#   image.onload = =>
#     gl.bindTexture(gl.TEXTURE_2D, texture)
#     gl.texImage2D(gl.TEXTURE_2D, level, internalFormat,
#                   srcFormat, srcType, image)

#     if (isPowerOf2(image.width) && isPowerOf2(image.height)) 
#        gl.generateMipmap(gl.TEXTURE_2D)
#     else
#        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
#        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
#        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
#   image.src = url
#   return texture




class Camera extends DisplayObject
  @generateAccessors()

  constructor: (cfg={}) ->
    super()
    @_dirtyCfg = new Lazy.Manager
    @_fov      = cfg.fov    || 60
    @_aspect   = cfg.aspect || 1
    @_near     = cfg.near   || 1
    @_far      = cfg.far    || 2000

    @__projectionMatrix     = mat4()
    @__viewMatrix           = mat4()

    @dirtyCfg.set()
    @update()

  @setter 'fov'    , (val) -> @_fov    = val; @dirtyCfg.set()
  @setter 'aspect' , (val) -> @_aspect = val; @dirtyCfg.set()
  @setter 'near'   , (val) -> @_near   = val; @dirtyCfg.set()
  @setter 'far'    , (val) -> @_far    = val; @dirtyCfg.set()
  @getter 'viewMatrix'       , -> @update(); @__viewMatrix
  @getter 'projectionMatrix' , -> @update(); @__projectionMatrix
  @getter 'variables'        , -> {@viewMatrix, @projectionMatrix, zoom: float 1}

  update: ->
    if @dirtyCfg.isSet
      fovRad = @fov * Math.PI / 180
      @_projectionMatrix.perspective fovRad, @aspect, @near, @far

    if @dirtyCfg.isSet || @transform.dirty.isSet
      super.update()
      @_viewMatrix.invertFrom @transform.matrix
    @dirtyCfg.unset()
    

class Sprite extends DisplayObject
  @generateAccessors()

  constructor: (@_system, @_id) ->
    super()
    @__varData = @system.geometry.instance.data

    @_variable = new Proxy {},
      get: (target, name)        => @getVariable name
      set: (target, name, value) => @setVariable name, value

  getVariable: (name) ->
    @_varData[name].read(@id)

  setVariable: (name, value) ->
    @getVariable(name).set value

  update: -> 
    if @transform.dirty.isSet
      super.update()
      # FIXME 1 : xform should be kept as Buffer
      # FIXME 2 : @xform causes update loop, maybe mixins?
      xf = new Buffer.Buffer Float32Array, @transform._matrix
      @_varData['modelMatrix'].read(@id).set xf


# builtinPattern = /([^ ]+) ([^(]+)(\([^)]*\))/
builtinPattern = /([^ ]+) ([^(]+)\(([^)]*)\)/
# argsPattern = /([^ ]+ [^ ]+ ?, ?)*/
# argsPattern = /(([^ ]+) ([^ ]+) ?,? ?)*/

redirectBuiltins = ->
  lines = builtins.split(/\r?\n/)
  names        = []
  redirections = []
  for line in lines
    match    = line.match builtinPattern
    outType  = match[1]
    fname    = match[2]
    argsStr  = match[3]
    args     = (v.split(' ') for v in argsStr.split(', '))
    argNames = (a[1] for a in args)
    redirection = "#{outType} overloaded_#{fname} (#{argsStr}) { return #{fname}(#{argNames.join(',')}); }"
    names.push fname
    redirections.push redirection
  code = redirections.join '\n'
  {code, names}

redirections = redirectBuiltins()

builtinsMap = new Set redirections.names


anyVar = /([a-zA-Z_])[a-zA-Z_0-9]*/gm
fragment_lib2 = fragment_lib.replace anyVar, (v) =>
  if builtinsMap.has v then "overloaded_#{v}" else v


allowOverloading = (src) -> 
  src2 = src.replace anyVar, (v) =>
    if builtinsMap.has v then "overloaded_#{v}" else v
  redirections.code + '\n' + src2


spriteBasciMaterialVertexShader = '''
void main() {
  local                = vec3((uv - 0.5) * bbox, 0.0);
  mat4 modelViewMatrix = viewMatrix * modelMatrix;
  vec4 eyeT            = modelViewMatrix * vec4(local,1.0);
  gl_Position          = projectionMatrix * eyeT;
  world                = gl_Position.xyz;  
  eye                  = eyeT.xyz;
  eye.z = -eye.z;
}
'''

spriteBasciMaterialFragmentShader= '''
void main() {
  output_color = vec4(1.0,0.0,0.0,1.0);
}
'''

# layout(location = 1) out vec4 outColor1;
# outColor1    = vec4(0.5,0.6,0.7,0.8);

export spriteBasicMaterial = (cfg={}) -> 
  new Material.Raw
    vertex:   cfg.vertex   || spriteBasciMaterialVertexShader
    fragment: cfg.fragment || spriteBasciMaterialFragmentShader
    locals:
      world : 'vec3'
      local : 'vec3'
      eye   : 'vec3'
    input:
      modelMatrix      : mat4
      viewMatrix       : mat4
      projectionMatrix : mat4
      uv               : vec2
      bbox             : vec2
      zoom             : float
    


export spriteBasicGeometry = (cfg) ->
  Geometry.rectangle # FIXME: exposes unnecessary var 'position'
    label    : "Sprite"
    width    : cfg.size || 100
    height   : cfg.size || 100
    instance :
      modelMatrix    : mat4()
      bbox           : vec2(cfg.size||100, cfg.size||100)
      symbolID       : float 0
      symbolFamilyID : float 0
      zIndex         : float 0


export class SpriteSystem extends DisplayObject
  @mixin Lazy.LazyManager

  constructor: (cfg={}) ->
    super()
    
    @mixins.constructor
      label       : @constructor.name
      lazyManager : new Lazy.ListManager

    @logger.group "Initializing", =>
      @_geometry = cfg.geometry || spriteBasicGeometry(cfg)
      @_material = cfg.material || spriteBasicMaterial(cfg)
      @_mesh     = Mesh.create @_geometry, @_material

  setVariable: (ix, name, data) ->
    @geometry.instance.data[name].read(ix).set data

  create: -> 
    ix     = @geometry.instance.add()
    sprite = new Sprite @, ix
    sprite.transform.dirty.onSet.addEventListener => @dirty.setElem sprite
    sprite

  update: ->
    @logger.group "Updating", =>
      @dirty.elems.forEach (elem) =>
        elem.update()
      @dirty.unset()




fragment_lib2 = allowOverloading fragment_lib

symbolBasciMaterialFragmentShader = (shapeShader) ->
  [fragment_lib2, shapeShader, fragmentRunner].join '\n'


export symbolBasicMaterial = (shapeShader, cfg) -> 
  spriteBasicMaterial Property.extend cfg,
    fragment: symbolBasciMaterialFragmentShader shapeShader


export class Symbol extends DisplayObject
  @mixin SpriteSystem

  constructor: (shape, cfg={}) -> 
    super()
    @mixins.constructor Property.extend cfg,
      material: symbolBasicMaterial shape.toShader().fragment
    @add @spriteSystem
   



frameRequested = false



resizeCanvasToDisplaySize = (canvas, multiplier) ->
  multiplier = multiplier || 1
  width  = canvas.clientWidth  * multiplier | 0
  height = canvas.clientHeight * multiplier | 0
  if (canvas.width != width ||  canvas.height != height)
    canvas.width  = width
    canvas.height = height
    true
  false








export test = (shape) ->
  scene = new Scene
    dom: 'test'
  gpuRenderer = new GPURenderer


  # v2 = scene.addView()
  # v2.camera.position.y = 60
  # v2.camera.position.z = 300

  scene.addRenderer gpuRenderer
  
  gl = gpuRenderer.gl

  ss  = new Symbol shape
  ss2 = new Symbol shape

  scene.add ss
  scene.add ss2


  sp1 = ss.create()
  sp1_2 = ss2.create()
  sp1_2.position.x = 100
  sp1_2.update()


  # console.log input_color.getGLTexture(gl)input_color
  # width  = gl.canvas.clientWidth 
  # height = gl.canvas.clientHeight

  # aspect = width / height

  # console.log ">>>", fsbox.shader.fragment
  # console.log ">>>", ss.shader.fragment

  
  # camera = scene.mainView.camera
  # camera = new Camera
  #   aspect: aspect

  # camera.position.z = 300



  {pbo, array2, size} = testx(gl, 1,1) # scene.width, scene.height)

  maxloops = 5 
  currentloop = 0
  
  cxc = 20
  renderloop = ->
    currentloop += 1
    # window.requestAnimationFrame renderloop
    # if frameRequested then return
    # frameRequested = true
    go()

  go = ->
    # camera.rotation.z += 0.1
    # console.log ""
    # console.log "---"
    sp1.position.x += 1
    # console.log sp1
    sp1.update()
    # console.log "---"
    # console.log ""
    # ss.update()
    # meshRegistry.update()
    # gpuRenderer.dirty.set()
    # gpuRenderer.render camera
    scene.render()

    # a = 0
    # for i in [0...1000000]
    #   for j in [0...10]
    #     a = i + j

    if cxc == 0 then return
    cxc -= 1

    window.requestAnimationFrame renderloop
    if frameRequested
      return
    frameRequested = true
    
    
    
    # ssm.draw(camera.viewProjectionMatrix)
    
    gl.bindBuffer gl.PIXEL_PACK_BUFFER, pbo
    # gl.readPixels 0, 0, scene.width, scene.height, gl.RGBA, gl.UNSIGNED_BYTE, 0
    gl.readPixels scene.mouse.x, scene.height-scene.mouse.y, 1, 1, gl.RGBA, gl.UNSIGNED_BYTE, 0
    # gl.readPixels(mouse.x, pickingTexture.height - mouse.y, 1, 1, gl.RGBA, gl.UNSIGNED_BYTE, 0);
    fence(gl).then ->
      gl.getBufferSubData gl.PIXEL_PACK_BUFFER, 0, array2, 0, 4
      gl.bindBuffer gl.PIXEL_PACK_BUFFER, null
      # console.log ">", array2
      render()
      gl.finish()

  renderloop()


render = ->
  frameRequested = false
  # renderer.render(scene, camera)  


testx = (gl, width, height) ->
  
  bytesPerPixel = 4
  bytesPerRow = width * bytesPerPixel
  size = bytesPerRow * height
  array  = new Uint8Array size
  array2 = new Uint8Array size
  pbo = gl.createBuffer()
  offset = 0
  gl.bindBuffer gl.PIXEL_PACK_BUFFER, pbo
  gl.bufferData gl.PIXEL_PACK_BUFFER, array, gl.DYNAMIC_READ
  gl.bindBuffer gl.PIXEL_PACK_BUFFER, null
  {pbo, array2, size}
  
fence = (gl) ->
  return new Promise (resolve) =>
    sync = gl.fenceSync gl.SYNC_GPU_COMMANDS_COMPLETE, 0
    gl.flush()
    check = () ->
      status = gl.getSyncParameter sync, gl.SYNC_STATUS
      if status == gl.SIGNALED
        gl.deleteSync sync
        resolve()
      else
        setTimeout check
    setTimeout check


class GPURenderer
  @mixin Lazy.LazyManager

  constructor: ->
    @mixins.constructor
      label: @constructor.name
    


    @_dom = document.createElement 'canvas'
    @_dom.style.width  = '100%'
    @_dom.style.height = '100%'

    @_gl = @_dom.getContext "webgl2"
      # premultipliedAlpha: false
    if !@_gl then throw "WebGL not supported"
    @_gl.blendFunc(@_gl.SRC_ALPHA, @_gl.ONE_MINUS_SRC_ALPHA);
    @_gl.enable(@_gl.BLEND);
    # gl.disable(gl.DEPTH_TEST);
    # @updateSize()

    @_attributeRegistry = new Variable.GPUAttributeRegistry @gl    
    @_gpuMeshRegistry   = new Mesh.GPUMeshRegistry          @gl
      
    @gpuMeshRegistry.dirty.onSet.addEventListener   => @dirty.set()
    @attributeRegistry.dirty.onSet.addEventListener => @dirty.set()

    @_meshes = new Map

    @renderViewsPass = renderViewsPass @
    @_pipeline = [@renderViewsPass, screenDrawPass @]
    @_pipelineInstance = null

  @getter 'width' , -> @dom.width
  @getter 'height', -> @dom.height
    


  add: (a) -> 
    @renderViewsPass.add a

  addMesh: (meshLike) ->
    mesh    = meshLike.mesh
    gpuMesh = @meshes.get mesh
    if not gpuMesh
      gpuMesh = new Mesh.GPUMesh @gl, @attributeRegistry, mesh
      @meshes.set mesh, gpuMesh
      @gpuMeshRegistry.add gpuMesh
      @dirty.set()
    gpuMesh

  updateSize: (width, height) -> 
    if (@dom.width != width || @dom.height != height)
      @dom.width  = width
      @dom.height = height
      @_gl.viewport 0, 0, width, height
      @_pipelineInstance = pipelineInstance @, @pipeline

  render: -> 
    runPipeline @pipelineInstance

  update: ->
    if @dirty.isSet
      @logger.group "Updating", =>
        @attributeRegistry.update()    
        @gpuMeshRegistry.update()
        @dirty.unset()

  handles: (obj) -> true # FIXME

  addView: ->
    new GPURendererView @



export class GPURendererView
  @generateAccessors()

  constructor: (@_renderer) ->
    @_instances = new Set

  add: (obj) ->
    instance = @renderer.add obj
    @instances.add instance

  render: (camera) ->
    @instances.forEach (instance) =>
      instance.draw camera

  handles: (obj) ->
    @renderer.handles obj
    



############
### Pass ### 
############

class Pass
  @generateAccessors()
  constructor: (cfg={}) ->
    @_inputs  = cfg.inputs  || []
    @_outputs = cfg.outputs || {}
    @_run     = cfg.run     || (->)
    @_update  = cfg.update  || (->)

  instance: (renderer) ->
    new PassInstance renderer, @



####################
### PassInstance ### 
####################

class PassInstance
  @generateAccessors()

  @getter 'gl', -> @renderer.gl

  constructor: (@_renderer, @pass) ->
    outputNum     = 0
    @textures     = {}
    @attachements = []
    @framebuffer  = null

    outputKeys = Object.keys @pass.outputs
    outputSize = outputKeys.length

    if outputSize > 0
      @framebuffer = @gl.createFramebuffer()
      @gl.bindFramebuffer @gl.FRAMEBUFFER, @framebuffer

      # Creating textures
      for outputNum in [0 ... outputSize]
        name        = outputKeys[outputNum]
        level       = 0
        noImage     = null
        texture_    = @gl.createTexture()
        attachement = @gl.COLOR_ATTACHMENT0 + outputNum
        @textures[name] = texture texture_
        @attachements.push attachement
        @gl.bindTexture @gl.TEXTURE_2D, texture_
        @gl.texImage2D @gl.TEXTURE_2D, level, @gl.RGBA, @renderer.width, @renderer.height, 0,  #FIXME literal
                       @gl.RGBA, @gl.UNSIGNED_BYTE, noImage
        @gl.texParameteri @gl.TEXTURE_2D, @gl.TEXTURE_MAG_FILTER, @gl.NEAREST
        @gl.texParameteri @gl.TEXTURE_2D, @gl.TEXTURE_MIN_FILTER, @gl.NEAREST
        @gl.framebufferTexture2D @gl.FRAMEBUFFER, attachement, @gl.TEXTURE_2D, 
                                 texture_, level

      @gl.bindFramebuffer @gl.FRAMEBUFFER, null # FIXME -> withFramebuffer

  run: (state) ->
    for output, texture_ of @textures
      state[output] = texture_
 
    if @framebuffer
      @gl.bindFramebuffer @gl.FRAMEBUFFER, @framebuffer
      @gl.clear @gl.COLOR_BUFFER_BIT
      @gl.blendFuncSeparate @gl.SRC_ALPHA, @gl.ONE_MINUS_SRC_ALPHA, @gl.ONE, @gl.ONE_MINUS_SRC_ALPHA                  
      @gl.drawBuffers @attachements
    @pass.run state
    if @framebuffer
      @gl.bindFramebuffer @gl.FRAMEBUFFER, null #FIXME -> withFramebuffer
      @gl.blendFunc @gl.SRC_ALPHA, @gl.ONE_MINUS_SRC_ALPHA #FIXME: should be there?    
    state


symbolMousePass = new Pass
  inputs: ['color', 'family', 'symbol']
  run: ->




######################
### ScreenDrawPass ###
######################

class ScreenDrawPass extends Pass
  @generateAccessors()

  constructor: (@_renderer, cfg={}) ->
    super()

    material = 
      new Material.Raw
        fragment: fullScreenFragmentShader

    geometry = Geometry.rectangle
      object :
        input_color: texture()

    @_fullScreenBox         = Mesh.create geometry, material
    @_fullScreenBoxInstance = @renderer.addMesh @fullScreenBox 

  run: (state) ->
    @fullScreenBox.geometry.object.data.input_color = state.color
    @fullScreenBoxInstance.draw()
    

screenDrawPass = (args...) -> new ScreenDrawPass args...


fullScreenFragmentShader = '''
void main() {
  vec3 uv = (position + 1.0) / 2.0;
  output_color = texture(input_color, uv.xy);
}
'''



######################
### RenderViewPass ###
######################

class RenderViewsPass extends Pass 
  @generateAccessors()

  constructor: (@_renderer, cfg={}) ->
    super
      outputs:
        color  : vec3
        family : float
        symbol : float
    @_camera   = cfg.camera ? new Camera
    @_width    = null
    @_height   = null
    @_elements = new Map

    @_views    = new Set
    @_mainView = @newView()

    @camera.position.z = 300

  newView: (cfg) -> 
    view = new View cfg
    @addView view
    view

  addView: (view) ->
    @views.add view
  

  # @setter 'width'  , (width)  -> @_width  = width  ; @updateSize()
  # @setter 'height' , (height) -> @_height = height ; @updateSize()
  
  update: (renderer) -> 
    @camera.aspect = renderer.width / renderer.height

  add: (element) ->
    instance = @renderer.addMesh element 
    @elements.set element, instance
    ## ## ## ## ## ##
    @mainView.add element

  run: ->
    @elements.forEach (instance) =>
      instance.draw @camera


renderViewsPass = (args...) -> new RenderViewsPass args...




class View
  @generateAccessors()

  constructor: (cfg={}) ->
    @_camera   = cfg.camera || new Camera
    @_elements = new Set

  add: (element) -> 
    @elements.add element



class ViewInstance



pipelineInstance = (renderer, passes) ->
  out = []
  for pass in passes
    pass.update renderer
    pi = pass.instance renderer
    out.push pi
  out

runPipeline = (pipeline) -> 
  state = {}
  for pass in pipeline
    state = pass.run state
  state


class Scene extends DisplayObject
  @generateAccessors()

  constructor: (cfg) -> 
    super()
    # @_views     = new Set
    @_renderers = new Set
    
    @_dom = new SceneDOM cfg
    @_dom.onResize.addEventListener (rect) =>
      @resize rect.width, rect.height
    @_dom.initSize()
    # @_mainView = @addView()

    # @_xView    = @addView() # FIXME HACK

    @_mouse = {x:0,y:0}

    window.addEventListener 'mousemove', (e) =>
      # Mouse position can be non integer and negative e.g. when div position
      # is non integer.
      @mouse.x = Math.min(@width ,Math.max(0,Math.round(e.x - @dom.position.x)))
      @mouse.y = Math.min(@height,Math.max(0,Math.round(e.y - @dom.position.y)))

  addRenderer: (renderer) ->
    @renderers.add renderer
    layer = @dom.addLayer renderer.label
    layer.appendChild renderer.dom
    renderer.updateSize @width, @height
    # @views.forEach (view) => 
    #   view.addRenderer renderer

  selectRenderer: (obj) ->
    for renderer from @renderers
      if renderer.handles obj
        return renderer
    return null

  add: (child) -> 
    # @mainView.add child
    Array.from(@renderers)[0].add child

  resize: (width, height) ->
    @_width  = width 
    @_height = height
    @renderers.forEach (renderer) =>
      renderer.updateSize width, height
    # @views.forEach (view) =>
    #   view.updateSize width, height

  # addView: (cfg) -> 
  #   view = new View cfg
  #   @views.add view
  #   for renderer from @renderers
  #     view.addRenderer renderer
  #   view

  render: ->
      # gpura = Array.from @renderers
      # gpur  = gpura[0]
      # gl    = gpur.gl
    
    # @renderers.forEach (renderer) =>
    #   renderer.begin()
    @renderers.forEach (renderer) =>
      renderer.update()
    @renderers.forEach (renderer) =>
      renderer.render()
    # @renderers.forEach (renderer) =>
    #   renderer.finish()
    
    # console.log gpur.textures
    # console.log ""
    # console.log "vvvvvvvvv"
      # screenT = texture gpur.textures[0]
      # @xView.mesh.geometry.object.data.input_color = screenT
      # @xView.render()
    # console.log "^^^^^^^^^"
    # console.log "" 


export scene = (args...) -> new Scene args...






# class View
#   @generateAccessors()

#   constructor: (cfg={}) ->
#     @_camera = cfg.camera ? new Camera
#     @_width  = null
#     @_height = null

#     @_scopes = new Map
#     @_renderers = new Set
#     @updateSize()

#   @setter 'width'  , (width)  -> @_width  = width  ; @updateSize()
#   @setter 'height' , (height) -> @_height = height ; @updateSize()

#   updateSize: (sceneWidth, sceneHeight) -> 
#     width  = @width  ? sceneWidth
#     height = @height ? sceneHeight
#     @camera.aspect = width / height

#   _selectRenderer: (obj) ->
#     for renderer from @renderers
#       if renderer.handles obj
#         return renderer
#     return null

#   add: (obj) ->
#     renderer = @_selectRenderer obj
#     if not renderer
#       msg = 'No registred renderer can handle the provided object'
#       throw {msg, obj}
    
#     scope = @scopes.get renderer
#     if not scope
#       scope = new Set
#       @scopes.set renderer, scope
#     scope.add obj
#     renderer.add obj

#   addRenderer: (renderer) ->
#     @renderers.add renderer.addView() 

#   render: ->
#     @renderers.forEach (renderer) =>
#       renderer.render @camera   


class SceneDOM
  @generateAccessors()

  constructor: (cfg={}) ->
    @_onResize = EventDispatcher.create()
    @_initDomElement cfg.dom

  _initDomElement: (cfg) ->
    @_element = null
    if cfg == undefined
      cfg = document.body
    if cfg != null
      parent = null
      if typeof cfg == 'string'
        parent = document.getElementById cfg
      else if cfg instanceof HTMLElement
        parent = cfg

      if parent == null
        msg = "Provided 'dom' is neither a valid DOM ID nor DOM element."
        throw {msg, cfg}

      @_element = document.createElement 'div'
      @_element.id            = 'scene'
      @_element.style.display = 'flex'
      @_element.style.width   = '100%'
      @_element.style.height  = '100%'
      parent.appendChild @_element
        
      resizeObserver = new ResizeObserver ([r]) =>
        @onResize.dispatch r.contentRect
      resizeObserver.observe @_element
      @refreshPosition_SLOW()

  # WARNING: This is slow, it requires whole DOM redraw.
  refreshPosition_SLOW: ->
    @_position = @_element.getBoundingClientRect()

  initSize: ->
    @onResize.dispatch
      width  : @_element.clientWidth
      height : @_element.clientHeight
      # @domLayer   = @addLayer 'dom'
      # @glLayer    = @addLayer 'gl'
      # @statsLayer = @addLayer 'stats'

      # @domLayer.style.pointerEvents = 'auto'

  addLayer: (name) =>
    layer = document.createElement 'div'
    layer.style.pointerEvents = 'none'
    layer.style.display       = 'flex'
    layer.style.margin        = 0
    layer.style.width         = '100%'
    layer.style.height        = '100%'
    layer.id                  = @element.id + '-layer-' + name
    @element.appendChild layer
    layer

  # refreshSize: () ->
  #   @geometry.resize @domElement.clientWidth, @domElement.clientHeight


  # #FIXME: read note in usage place
  # updateSizeSLOW: () ->
  #   dwidth  = @domElement.clientWidth
  #   dheight = @domElement.clientHeight
  #   if dwidth != @width || dheight != @height
  #     @geometry.resize @domElement.clientWidth, @domElement.clientHeight

  # disableDOMLayerPointerEvents: () -> @domLayer.style.pointerEvents = 'none'
  # enableDOMLayerPointerEvents : () -> @domLayer.style.pointerEvents = 'auto'




# shape1 = basegl.shape ...

# symbol1 = basegl.symbol shape1

# scene.add symbol1


