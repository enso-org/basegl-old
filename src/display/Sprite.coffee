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
import {vec2, vec3, vec4, mat2, mat3, mat4, Vec3} from 'basegl/data/vector'
import * as _ from 'lodash'

import * as M from 'gl-matrix'


import * as Display from 'basegl/display/object'


import {EventObject} from 'basegl/display/object/event'
import {DisplayObject} from 'basegl/display/object'
import {Logged} from 'basegl/object/logged'



export test2 = (gl, viewProjectionMatrix) ->

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


  attrRegistry = new Variable.GPUAttributeRegistry gl
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

  m1 = new Mesh.GPUMesh gl, attrRegistry, mesh
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
    if @dirty.isSet
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
  @mixin Lazy.LazyManager

  constructor: ->
    @mixins.constructor
      label       : @constructor.name
      lazyManager : new Lazy.ListManager

    @logger.group "Initializing", =>
      @_geometry = Geometry.rectangle
        label    : "Sprite"
        width    : 200
        height   : 200
        instance :
          color:     vec4()
          transform: mat4()
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
    @geometry.instance.data[name].read(ix).set data

  create: -> 
    ix     = @geometry.instance.add()
    sprite = new Sprite @, ix
    sprite.dirty.onSet.addEventListener => @dirty.setElem sprite
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
  # ssm = gpuRenderer.addMesh ss

  scene.add ss

  sp1 = ss.create()
  sp1.variable.color.rgb = [0,0,1]
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
    window.requestAnimationFrame renderloop
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
    if @dirty.isSet || camera.dirty.isSet
      @logger.group "Updating", =>
        @attributeRegistry.update()    
        @gpuMeshRegistry.update()
        @gpuMeshRegistry.forEach (gpuMesh) =>
          gpuMesh.draw camera.viewProjectionMatrix
        @dirty.unset()

  handles: (obj) -> true # FIXME




class Pass
  @generateAccessors()
  constructor: ->



class Scene
  @generateAccessors()

  constructor: (@_gl, cfg) -> 
    @_views     = new Set
    @_renderers = new Set
    
    @_dom = new SceneDOM cfg
    @_dom.onResize.addEventListener (rect) =>
      @resize rect.width, rect.height
    @newView()

  addRenderer: (renderer) ->
    @renderers.add renderer
    layer = @dom.addLayer renderer.label
    layer.appendChild renderer.dom
    renderer.updateSize()

  add: (obj) ->
    for renderer from @renderers
      if renderer.handles obj
        return renderer.add obj

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


