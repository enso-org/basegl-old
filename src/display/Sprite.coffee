import * as Config   from 'basegl/object/config'
import * as Variable from 'basegl/display/symbol/3D/geometry/variable'
import * as Geometry from 'basegl/display/symbol/3D/geometry'
import * as Material from 'basegl/display/symbol/3D/material'
import * as Mesh     from 'basegl/display/symbol/3D/mesh'
import * as Lazy     from 'basegl/object/lazy'
import * as Property from 'basegl/object/Property'
import * as Buffer   from 'basegl/data/buffer'

import {logger}                             from 'logger'
import {vec2, vec3, vec4, mat2, mat3, mat4, Vec3} from 'basegl/data/vector'
import * as _ from 'lodash'

import * as M from 'gl-matrix'


import * as Display from 'basegl/display/object'


import {EventObject} from 'basegl/display/object/event'
import {DisplayObject} from 'basegl/display/object'
import {Logged} from 'basegl/object/logged'



export test2 = (ctx, viewProjectionMatrix) ->

  geo = Geometry.rectangle
    label    : "Geo1"
    width    : 200
    height   : 200
    instance :
      transform: [mat4(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-100), mat4()]
    object:
      matrix: mat4
      

  # geo = Geometry.create
  #   label: "Geo1"
  #   point:
  #     position: 
  #       usage : Variable.usage.static
  #       data  : [
  #         (vec3 -100,  100, 0),
  #         (vec3 -100, -100, 0),
  #         (vec3  100,  100, 0),
  #         (vec3  100, -100, 0)]
  #     uv: [
  #       # usage : usage.static
  #       # data  : [
  #         (vec2 0,1),
  #         (vec2 0,0),
  #         (vec2 1,1),
  #         (vec2 1,0)] 

  #     # color: 
  #     #   type: vec4
  #     #   data: new Float32Array [
  #     #     1,0,0,1,
  #     #     0,1,0,1,
  #     #     0,0,1,1,
  #     #     1,1,1,1]

  #     # color: [
  #     #   (vec4 1,0,0,1),
  #     #   (vec4 0,1,0,1),
  #     #   (vec4 0,0,1,1),
  #     #   (vec4 1,1,1,1)
  #     # ]

  #     # color: 
  #     #   type: vec4
  #     #   default: [1,0,0,1,0,1,0,1]
      
  #     # transform: [
  #     #   (mat4 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,100) ,
  #     #   (mat4 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0) ,
  #     #   (mat4 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0) ,
  #     #   (mat4 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0) ]
      
  #   instance:
  #   #   # color: vec4
  #   #   # color: [
  #   #   #   (vec4 1,0,0,1)] # , (vec4 0,1,0,1) ]
  #   #   # color: 
  #   #   #   data: vec4(1,0,0,1)
  #   #   #   default: [1,0,1]
  #     transform: [mat4(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-100), mat4()]
  #     # foo: [1,2]

  #   object:
  #     matrix: mat4


  attrRegistry = new Variable.GPUAttributeRegistry ctx
  meshRegistry = new Mesh.GPUMeshRegistry


  vertexShaderSource = '''
  void main() {
    gl_Position = matrix * v_position;
    gl_Position.x += v_transform[3][3];
  }
  '''

  fragmentShaderSource = '''
  out vec4 output_color;  
  void main() {
    output_color = color;
  }'''

  fragmentShaderSource2 = '''
  out vec4 output_color;  
  void main() {
    output_color = vec4(0,1,0,1);
  }'''

  mat1 = new Material.Raw
    vertex   : vertexShaderSource
    fragment : fragmentShaderSource
    input:
      position  : vec4()
      transform : mat4()
      matrix    : mat4()
      color     : vec4 0,1,0,1
  mesh = Mesh.create geo, mat1

  m1 = new Mesh.GPUMesh ctx, attrRegistry, mesh
  meshRegistry.add m1



  # console.log mat1.shader
  # mat1.writePointVariable 'position', (vec4 [0,0,0,0])
  # mat1.writePointVariable 'color', (vec4 [0,0,0,1])
  # mat1.writePointVariable 'uv', (vec2 [0,0])
  # mat1.writeObjectVariable 'matrix', (mat4 [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0])
  # mat1.writeOutputVariable 'color', (vec4 [0,0,0,0])
  # console.log mat1.shader.vertex
  # console.log mat1.shader.fragment

  logger.group "FRAME 1", =>
    # geo.point.data.position.read(0)[0] = 7
    # console.log geo.instance.data.color
    geo.instance.addAttribute 'color', 
      type: vec4
      default: vec4(1,0,0,1)
    # mat1.fragment = fragmentShaderSource2
    meshRegistry.update()
    attrRegistry.update()
    # meshRegistry.update()
  
  logger.group "FRAME 2", =>
    geo.instance.data.color.read(0).rgba = [1,1,0,1]
    geo.instance.data.color.read(1).rgba = [0,1,0,1]
    # geo.point.data.position.read(0)[0] = 7
  #   geo.point.data.position.read(0)[0] = 7
  #   geo.point.data.position.read(0)[1] = 7
    attrRegistry.update()
    meshRegistry.update()

  logger.group "FRAME 3", =>
  #   # geo.point.data.position.read(1)[0] = 8
  #   # geo.point.data.uv.read(1)[0] = 8
  #   # geo.instance.add({color: vec4(0,0,1,1)})
  #   geo.instance.add({color: vec4(0,1,0,1), transform:mat4(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,10)})
  #   # geo.instance.add({color: vec4(0,0,0,1)})
  #   # geo.instance.data.color.read(0)[0] = 0.7
    attrRegistry.update()
    meshRegistry.update()

  # logger.group "FRAME 4", =>
  #   attrRegistry.update()
  #   # meshRegistry.update()


  m1.draw(viewProjectionMatrix)
  


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
    @__viewProjectionMatrix = M.mat4.create()

    @dirtyCfg.set()
    @update()

  @setter 'fov'    , (val) -> @_fov    = val; @dirtyCfg.set()
  @setter 'aspect' , (val) -> @_aspect = val; @dirtyCfg.set()
  @setter 'near'   , (val) -> @_near   = val; @dirtyCfg.set()
  @setter 'far'    , (val) -> @_far    = val; @dirtyCfg.set()
  @getter 'viewProjectionMatrix', ->
    @update()
    @__viewProjectionMatrix

  update: ->
    if @dirtyCfg.isSet
      fovRad = @fov * Math.PI / 180
      M.mat4.perspective @_projectionMatrix, fovRad, @aspect, @near, @far

    if @dirtyCfg.isSet || @dirty.isSet
      super.update()
      M.mat4.invert   @_viewMatrix, @_xform
      M.mat4.multiply @_viewProjectionMatrix, @_projectionMatrix, @_viewMatrix
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
    super.update()
    # FIXME 1 : xform should be kept as Buffer
    # FIXME 2 : @xform causes update loop, maybe mixins?
    xf = new Buffer.Buffer Float32Array, @_xform
    @_varData['transform'].read(@id).set xf



spriteVertexShaderBase = '''
vec4 xpos;
void main() {
  xpos = v_transform * v_position;
  gl_Position = matrix * xpos;
}
'''

spriteFragmentShaderBase = '''
out vec4 output_color;  
void main() {
  output_color = color;
}'''

class SpriteSystem
  @mixin Logged

  constructor: ->
    @mixins.constructor
      label: @constructor.name

    @logger.group "Initializing", =>
      @_geometry = Geometry.rectangle
        label    : "Sprite"
        width    : 200
        height   : 200
        instance :
          color:     vec4()
          transform: [mat4(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-100), mat4()]
        object:
          matrix: mat4

      @_material = new Material.Raw
        vertex   : spriteVertexShaderBase
        fragment : spriteFragmentShaderBase
        input:
          position  : vec4()
          transform : mat4()
          matrix    : mat4()
          color     : vec4 0,1,0,1

      @_mesh = Mesh.create @_geometry, @_material

  setVariable: (ix, name, data) ->
    console.warn "SET", ix, name, data
    @geometry.instance.data[name].read(ix).set data

  create: -> 
    ix = @geometry.instance.add({color: vec4(1,0,0,1), transform:mat4(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,20)})
    new Sprite @, ix



export test = (ctx) ->

  geo = Geometry.rectangle
    label    : "Geo1"
    width    : 200
    height   : 200
    instance :
      transform: [mat4(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-100), mat4()]
    object:
      matrix: mat4
      

  attrRegistry = new Variable.GPUAttributeRegistry ctx
  meshRegistry = new Mesh.GPUMeshRegistry


  vertexShaderSource = '''
  void main() {
    gl_Position = matrix * v_position;
    gl_Position.x += v_transform[3][3];
  }
  '''

  fragmentShaderSource = '''
  out vec4 output_color;  
  void main() {
    output_color = color;
  }'''

  fragmentShaderSource2 = '''
  out vec4 output_color;  
  void main() {
    output_color = vec4(0,1,0,1);
  }'''

  mat1 = new Material.Raw
    vertex   : vertexShaderSource
    fragment : fragmentShaderSource
    input:
      position  : vec4()
      transform : mat4()
      matrix    : mat4()
      color     : vec4 0,1,0,1
  mesh = Mesh.create geo, mat1

  m1 = new Mesh.GPUMesh ctx, attrRegistry, mesh
  meshRegistry.add m1


  ss  = new SpriteSystem
  ssm = new Mesh.GPUMesh ctx, attrRegistry, ss.mesh
  meshRegistry.add ssm

  sp1 = ss.create()
  sp1.variable.color.rgb = [0,0,1]
  

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

  logger.group "TEST FRAME 1", =>
    # geo.point.data.position.read(0)[0] = 7
    # console.log geo.instance.data.color
    geo.instance.addAttribute 'color', 
      type: vec4
      default: vec4(1,0,0,1)
    # mat1.fragment = fragmentShaderSource2
    meshRegistry.update()
    attrRegistry.update()
    # meshRegistry.update()
  
  logger.group "TEST FRAME 2", =>
    geo.instance.data.color.read(0).rgba = [1,1,0,1]
    geo.instance.data.color.read(1).rgba = [0,1,0,1]
    # geo.point.data.position.read(0)[0] = 7
  #   geo.point.data.position.read(0)[0] = 7
  #   geo.point.data.position.read(0)[1] = 7
    attrRegistry.update()
    meshRegistry.update()

  logger.group "TEST FRAME 3", =>
  #   # geo.point.data.position.read(1)[0] = 8
  #   # geo.point.data.uv.read(1)[0] = 8
  #   # geo.instance.add({color: vec4(0,0,1,1)})
  #   geo.instance.add({color: vec4(0,1,0,1), transform:mat4(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,10)})
  #   # geo.instance.add({color: vec4(0,0,0,1)})
  #   # geo.instance.data.color.read(0)[0] = 0.7
    attrRegistry.update()
    meshRegistry.update()

  # logger.group "TEST FRAME 4", =>
  #   attrRegistry.update()
  #   # meshRegistry.update()

  aspect = ctx.canvas.clientWidth / ctx.canvas.clientHeight;

  
  camera = new Camera
    aspect: aspect

  camera.position.z = 300

  fms = 0
  drawMe = ->
    logger.group "FRAME #{fms}", =>
      # ctx.clearColor(0, 0, 0, 0);
      # ctx.clear(ctx.COLOR_BUFFER_BIT | ctx.DEPTH_BUFFER_BIT);

      camera.rotation.z += 0.1
      sp1.position.x += 10

      sp1.update()
      attrRegistry.update()
      meshRegistry.update()



      ssm.draw(camera.viewProjectionMatrix)
        
      if fms < 100
        fms += 1
        window.requestAnimationFrame(drawMe)
  drawMe()
  


# class Sprite
#   constructor: ->
#     @_geometry = 


