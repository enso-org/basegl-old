import * as Config   from 'basegl/object/config'
import * as Variable from 'basegl/display/symbol/3D/geometry/variable'
import * as Geometry from 'basegl/display/symbol/3D/geometry'
import * as Material from 'basegl/display/symbol/3D/material'
import * as Mesh     from 'basegl/display/symbol/3D/mesh'
import * as Lazy     from 'basegl/object/lazy'
import * as Property from 'basegl/object/Property'
import * as EventDispatcher from 'basegl/event/dispatcher'
import * as Buffer   from 'basegl/data/buffer'

import {logger}                             from 'logger'
import {vec2, vec3, vec4, mat2, mat3, mat4, Vec3, float} from 'basegl/data/vector'
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




class Camera extends DisplayObject
  @generateAccessors()

  constructor: (cfg={}) ->
    super()
    @_dirtyCfg = new Lazy.Manager
    @_fov      = cfg.fov    || 60
    @_aspect   = cfg.aspect || 1
    @_near     = cfg.near   || 1
    @_far      = cfg.far    || 2000

    @__projectionMatrix     = M.mat4.create()
    @__viewMatrix           = M.mat4.create()
    # @__viewProjectionMatrix = M.mat4.create()

    @dirtyCfg.set()
    @update()

  @setter 'fov'    , (val) -> @_fov    = val; @dirtyCfg.set()
  @setter 'aspect' , (val) -> @_aspect = val; @dirtyCfg.set()
  @setter 'near'   , (val) -> @_near   = val; @dirtyCfg.set()
  @setter 'far'    , (val) -> @_far    = val; @dirtyCfg.set()
  # @getter 'viewProjectionMatrix', ->
  #   @update()
  #   @__viewProjectionMatrix
  @getter 'viewMatrix', ->
    @update()
    @__viewMatrix
  @getter 'projectionMatrix', ->
    @update()
    @__projectionMatrix

  update: ->
    if @dirtyCfg.isSet
      fovRad = @fov * Math.PI / 180
      M.mat4.perspective @_projectionMatrix, fovRad, @aspect, @near, @far

    if @dirtyCfg.isSet || @transform.dirty.isSet
      super.update()
      M.mat4.invert   @_viewMatrix, @transform.matrix
      # M.mat4.multiply @_viewProjectionMatrix, @_projectionMatrix, @_viewMatrix
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
    if @dirty.isSet
      super.update()
      # FIXME 1 : xform should be kept as Buffer
      # FIXME 2 : @xform causes update loop, maybe mixins?
      xf = new Buffer.Buffer Float32Array, @_xform
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
    # console.log line.replace(builtinPattern, "$1 overloaded_$2 $3 { return $2$3 }")
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


spriteVertexShaderBase = '''

out vec3 world;
out vec3 local;
out vec3 eye;

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

spriteFragmentShaderBase = '''
in vec3  world;
in vec3  local;
in vec3  eye;

out vec4 output_color;  
''' + redirections.code + '\n' + fragment_lib2 + '\n' +

'''

sdf_shape _main(vec2 p) {
float shape_1   = sdf_circle(p,50.0);
vec4  shape_1_bb = bbox_new(50.0,50.0);
vec4  shape_1_cd = rgb2lch(vec4(1,0,0,1));
int shape_1_id = newIDLayer(shape_1, 1);
float shape_2   = sdf_circle(p,30.0);
vec4  shape_2_bb = bbox_new(30.0,30.0);
vec4  shape_2_cd = rgb2lch(vec4(1,0,0,1));
int shape_2_id = newIDLayer(shape_2, 2);
float shape_3   = sdf_difference(shape_1,shape_2);
vec4  shape_3_bb = bbox_union(shape_1_bb,shape_2_bb);
vec4  shape_3_cd = shape_1_cd;
int shape_3_id = id_difference(shape_1, shape_2, shape_1_id);
return sdf_shape(shape_3, shape_3_id, shape_3_bb, shape_3_cd);
}

''' + fragmentRunner

class SpriteSystem extends DisplayObject
  @mixin Lazy.LazyManager

  constructor: (cfg={}) ->
    super()
    
    @mixins.constructor
      label       : @constructor.name
      lazyManager : new Lazy.ListManager

    @logger.group "Initializing", =>
      @_geometry = cfg.geometry || Geometry.rectangle
        label    : "Sprite"
        width    : cfg.size || 100
        height   : cfg.size || 100
        instance :
          modelMatrix    : mat4()
          bbox           : vec2(cfg.size||100, cfg.size||100)
          symbolID       : float 0
          symbolFamilyID : float 0
          zIndex         : float 0
        object:
          viewMatrix       : mat4
          projectionMatrix : mat4
          zoom             : float 1 # FIXME, hardcoded in mesh rendering

      @_material = cfg.material || new Material.Raw
        vertex   : cfg.shader?.vertex   || spriteVertexShaderBase
        fragment : cfg.shader?.fragment || spriteFragmentShaderBase
        input:
          modelMatrix      : mat4()
          viewMatrix       : mat4()
          projectionMatrix : mat4()
          uv               : vec2()
          bbox             : vec2()
          symbolID         : float()
          symbolFamilyID   : float()
          zoom             : float()
          zIndex           : float()

      @_mesh = Mesh.create @_geometry, @_material

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

export test = () ->
  scene = new Scene
  gpuRenderer = new GPURenderer
  scene.addRenderer gpuRenderer
  
  # canvas = document.createElement 'canvas'
  # canvas.style.width  = '100%'
  # canvas.style.height = '100%'
  # scene.dom.element.appendChild canvas

  # gl = canvas.getContext("webgl2")
  # if (!gl) 
  #   return

  # resizeCanvasToDisplaySize gl.canvas
  # gl.viewport 0, 0, gl.canvas.width, gl.canvas.height
  gl = gpuRenderer.gl


  # geo = Geometry.rectangle
  #   label    : "Geo1"
  #   width    : 200
  #   height   : 200
  #   instance :
  #     transform: [mat4(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-100), mat4()]
  #   object:
  #     matrix: mat4
      

  # attrRegistry = new Variable.GPUAttributeRegistry gl
  # meshRegistry = new Mesh.GPUMeshRegistry gl


  # vertexShaderSource = '''
  # void main() {
  #   gl_Position = matrix * v_position;
  #   gl_Position.x += v_transform[3][3];
  # }
  # '''

  # fragmentShaderSource = '''
  # out vec4 output_color;  
  # void main() {
  #   output_color = color;
  # }'''

  # fragmentShaderSource2 = '''
  # out vec4 output_color;  
  # void main() {
  #   output_color = vec4(0,1,0,1);
  # }'''

  # mat1 = new Material.Raw
  #   vertex   : vertexShaderSource
  #   fragment : fragmentShaderSource
  #   input:
  #     position  : vec4()
  #     transform : mat4()
  #     matrix    : mat4()
  #     color     : vec4 0,1,0,1
  # mesh = Mesh.create geo, mat1

  # m1 = new Mesh.GPUMesh gl, attrRegistry, mesh
  # meshRegistry.add m1


  ss  = new SpriteSystem

  console.log fragmentHeader
  console.log fragmentRunner
  console.log ss.mesh.shader.vertex
  # console.log ss.mesh.shader.vertex
  # ssm = gpuRenderer.addMesh ss

  scene.add ss

  sp1 = ss.create()
  # sp1.variable.color.rgb = [0,0,1]
  # console.log sp1
  

  # sp1.position.x = 100
  # ss.setVariable 0, 'color', vec4(0,1,0,1)

  # console.warn ">>>"
  # console.log sp1.getVariable 'color'


  # console.log mat1.shader
  # mat1.writePointVariable 'position', (vec4 [0,0,0,0])
  # mat1.writePointVariable 'color', (vec4 [0,0,0,1])
  # mat1.writePointVariable 'uv', (vec2 [0,0])
  # mat1.writeObjectVariable 'matrix', (mat4 [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0])
  # mat1.writeOutputVariable 'color', (vec4 [0,0,0,0])
  # console.log mat1.shader.vertex
  # console.log mat1.shader.fragment

  # logger.group "TEST FRAME 1", =>
  #   # geo.point.data.position.read(0)[0] = 7
  #   # console.log geo.instance.data.color
  #   geo.instance.addAttribute 'color', 
  #     type: vec4
  #     default: vec4(1,0,0,1)
  #   # mat1.fragment = fragmentShaderSource2
  #   meshRegistry.update()
  #   meshRegistry._attributeRegistry.update()
  #   # meshRegistry.update()
  
  # logger.group "TEST FRAME 2", =>
  #   geo.instance.data.color.read(0).rgba = [1,1,0,1]
  #   geo.instance.data.color.read(1).rgba = [0,1,0,1]
  #   # geo.point.data.position.read(0)[0] = 7
  # #   geo.point.data.position.read(0)[0] = 7
  # #   geo.point.data.position.read(0)[1] = 7
  #   attrRegistry.update()
  #   meshRegistry.update()

  # logger.group "TEST FRAME 3", =>
  # #   # geo.point.data.position.read(1)[0] = 8
  # #   # geo.point.data.uv.read(1)[0] = 8
  # #   # geo.instance.add({color: vec4(0,0,1,1)})
  # #   geo.instance.add({color: vec4(0,1,0,1), transform:mat4(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,10)})
  # #   # geo.instance.add({color: vec4(0,0,0,1)})
  # #   # geo.instance.data.color.read(0)[0] = 0.7
  #   attrRegistry.update()
  #   meshRegistry.update()

  # logger.group "TEST FRAME 4", =>
  #   attrRegistry.update()
  #   # meshRegistry.update()

  # s = new Scene gl
  

  width  = gl.canvas.clientWidth 
  height = gl.canvas.clientHeight

  aspect = width / height

  
  camera = new Camera
    aspect: aspect

  camera.position.z = 300



  {pbo, array2, size} = testx(gl, width, height)

  maxloops = 5 
  currentloop = 0
 
  renderloop = ->
    currentloop += 1
    # window.requestAnimationFrame renderloop
    if frameRequested then return
    frameRequested = true
    go()

  go = ->
    camera.rotation.z += 0.1
    # sp1.position.x += 1
    # sp1.update()
    ss.update()
    # meshRegistry.update()
    # gpuRenderer.dirty.set()
    gpuRenderer.render camera

    # a = 0
    # for i in [0...1000000]
    #   for j in [0...20]
    #     a = i + j
    
    # ssm.draw(camera.viewProjectionMatrix)
    
    gl.bindBuffer gl.PIXEL_PACK_BUFFER, pbo
    gl.readPixels 0, 0, width, height, gl.RGBA, gl.UNSIGNED_BYTE, 0
    # gl.readPixels(mouse.x, pickingTexture.height - mouse.y, 1, 1, gl.RGBA, gl.UNSIGNED_BYTE, 0);
    fence(gl).then ->
      gl.getBufferSubData gl.PIXEL_PACK_BUFFER, 0, array2, 0, 4
      gl.bindBuffer gl.PIXEL_PACK_BUFFER, null
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

  constructor: () ->
    @mixins.constructor
      label: @constructor.name
    


    @_dom = document.createElement 'canvas'
    @_dom.style.width  = '100%'
    @_dom.style.height = '100%'

    @_gl = @_dom.getContext("webgl2")
    if !@_gl then throw "WebGL not supported"
    @updateSize()

    @_attributeRegistry = new Variable.GPUAttributeRegistry @gl    
    @_gpuMeshRegistry   = new Mesh.GPUMeshRegistry          @gl
      
    # @gpuMeshRegistry.dirty.onSet.addEventListener   => @dirty.set()
    # @attributeRegistry.dirty.onSet.addEventListener => @dirty.set()

  add: (a) -> 
    @addMesh a

  addMesh: (meshLike) ->
    mesh    = meshLike.mesh
    gpuMesh = new Mesh.GPUMesh @gl, @attributeRegistry, mesh
    @gpuMeshRegistry.add gpuMesh
    @dirty.set()

  updateSize: -> 
    width  = @dom.clientWidth 
    height = @dom.clientHeight
    if (@dom.width != width ||  @dom.height != height)
      @dom.width  = width
      @dom.height = height
      @_gl.viewport 0, 0, width, height
      true
    false
    

  render: (camera) ->
    if @dirty.isSet || camera.transform.dirty.isSet
      @logger.group "Updating", =>
        @attributeRegistry.update()    
        @gpuMeshRegistry.update()
        @gpuMeshRegistry.forEach (gpuMesh) =>
          gpuMesh.draw camera #.viewProjectionMatrix
        @dirty.unset()

  handles: (obj) -> true # FIXME




class Pass
  @generateAccessors()
  constructor: ->



class Scene extends DisplayObject
  @generateAccessors()

  constructor: (@_gl, cfg) -> 
    super()
    @_views     = new Set
    @_renderers = new Set
    
    @_dom = new SceneDOM cfg
    @_dom.onResize.addEventListener (rect) =>
      @resize rect.width, rect.height
    @newView()

    # @onChildAdded.addEventListener, (child) => @_add child

  addRenderer: (renderer) ->
    @renderers.add renderer
    layer = @dom.addLayer renderer.label
    layer.appendChild renderer.dom
    renderer.updateSize()

  add: (child) ->
    super.add child
    for renderer from @renderers
      if renderer.handles child
        return renderer.add child

    msg = 'No registred renderer can handle the provided object'
    throw {msg, obj}

  resize: (width, height) ->
    @_width  = width 
    @_height = height
    @views.forEach (view) =>
      view.updateSize()

  newView: (cfg) -> 
    view = new View @, cfg
    @views.add view
    view




class View
  @generateAccessors()

  constructor: (@_scene, cfg={}) ->
    @_camera = cfg.camera ? new Camera
    @_width  = null
    @_height = null
    @updateSize()

  @setter 'width'  , (width)  -> @_width  = width  ; @updateSize()
  @setter 'height' , (height) -> @_height = height ; @updateSize()

  updateSize: -> 
    width  = @_width  ? @scene.width
    height = @_height ? @scene.height
    @camera.aspect = width / height



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
      @_element.id            = 'basegl-scene'
      @_element.style.display = 'flex'
      @_element.style.width   = '100%'
      @_element.style.height  = '100%'
      parent.appendChild @_element
        
      resizeObserver = new ResizeObserver ([r]) =>
        @onResize.dispatch r.contentRect
      #   @geometry.resize r.contentRect.width, r.contentRect.height
      resizeObserver.observe @_element


      # @domLayer   = @addLayer 'dom'
      # @glLayer    = @addLayer 'gl'
      # @statsLayer = @addLayer 'stats'

      # @domLayer.style.pointerEvents = 'auto'

  addLayer: (name) =>
    layer = document.createElement 'div'
    layer.style.pointerEvents = 'none'
    layer.style.position      = 'absolute'
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


