import {DisplayObject, POINTER_EVENTS}    from 'basegl/display/DisplayObject'
import {SymbolGeometry, SymbolFamily, DRAW_BUFFER}    from 'basegl/display/Symbol'
import {Camera, GLCamera}  from 'basegl/navigation/Camera'
import {animationManager}  from 'basegl/animation/Manager'
import {disableBubbling}   from 'basegl/event/EventDispatcher'
import {Shape}             from 'basegl/display/Shape'
import {IdxPool}           from 'basegl/lib/container/Pool'
import {Stats}             from 'basegl/lib/Stats'
import {setObjectProperty} from 'basegl/object/Property'
import * as World from 'basegl/display/World'

import * as Color from 'basegl/display/Color'
import * as Debug from 'basegl/debug/GLInspector'
import * as Property    from 'basegl/object/Property'
import {define, mixin, configure, configureLazy, params, lazy, configure2, Composition, Composable, fieldMixin, extend} from 'basegl/object/Property'

import {eventDispatcherMixin} from 'basegl/event/EventDispatcher'

require('basegl/display/render/CSS3DRenderer')


unsafeWithReparented = (a, newParent, f) ->
  oldParent = a._parent
  a._parent = newParent
  out = f()
  a._parent = oldParent
  out


export class SymbolTargetPath
  constructor: (@symbolFamilyID=0, @symbolID=0, @shapeID=0) ->
  compare: (t) -> (@compareSymbol t) && (@shapeID == t.shapeID)
  compareSymbol: (t) -> (@symbolFamilyID == t.symbolFamilyID) && (@symbolID == t.symbolID)

export class SymbolTarget
  constructor: (@path=new SymbolTargetPath, @symbol=null, @shapeDef=null, @element=null) ->

  runInContext: (f) ->
    if @shapeDef? then unsafeWithReparented @shapeDef, @symbol, f
    else f()

  getParentChain: -> 
    @runInContext => @element.getParentChain()

  dispatchEvent: (e) ->
    setObjectProperty e, 'symbol', @symbol
    setObjectProperty e, 'shapeDef', @shapeDef
    @runInContext => @element.dispatchEvent e

  discoverPointerEventTarget: () ->
    pointerEventTargetDiscovery = () ->
      enabled = true
      test = (a) ->
        result = null
        switch a.style.pointerEvents
          when POINTER_EVENTS.INHERIT  then result = enabled
          when POINTER_EVENTS.ENABLED  then result = true
          when POINTER_EVENTS.DISABLED then result = false
        switch a.style.childrenPointerEvents
          when POINTER_EVENTS.INHERIT  then enabled = result
          when POINTER_EVENTS.ENABLED  then enabled = true
          when POINTER_EVENTS.DISABLED then enabled = false
        result
      test
    @runInContext => @element.captureBy(pointerEventTargetDiscovery())



export class MaterialStore
  constructor: () ->
    @materials = new Set
    @uniforms  = new Proxy {},
      set: (target, name, val) =>
        @setUniform name, val
        true

  add: (m) -> @materials.add m

  setUniform: (name, val) ->
    @materials.forEach (mat) ->
      mat.uniforms[name].value = val



# export class SceneGeo extends Composable
#   cons: (cfg) ->
#     @_width      = 256
#     @_height     = 256
#     @_autoResize = true
#     @configure cfg
#
#   init: -> if @autoResize
#     animationManager.addEveryDrawAnimation @onEveryFrame.bind(@)
#
# sceneGeoMixin = fieldMixin SceneGeo


#####################
### SceneGeometry ###
#####################

export class SceneGeometry extends Composable
  cons: (cfg) ->
    @_width  = 256
    @_height = 256
    @configure cfg

  resize: (w,h) ->
    @_width  = w
    @_height = h
    @onResized()

  onResized: ->



################
### SceneDom ###
################

class SceneDOM extends Composable
  cons: (cfg) ->
    @_geometry   = @mixin SceneGeometry, cfg
    @_domElement = null
    @_autoResize = true
    @configure cfg

  @getter 'onscreen',  -> @domElement != null
  @getter 'offscreen', -> not @onscreen

  init: ->
    if @domElement != null
      domID = @domElement
      if typeof @domElement == 'string'
        @_domElement = document.getElementById domID
      if not @domElement instanceof HTMLElement
        msg = "Provided `domElement` is neither a valid DOM ID nor DOM element."
        raise {msg, domID}
      @refreshSize()
      if @autoResize
        # TODO: SLOW! Unless we've got pure Electtron app with flags access
        # we use this. After enabling chrome://flags/#enable-experimental-web-platform-features
        # switch to the commented code
        animationManager.addEveryDrawAnimation @updateSizeSLOW.bind(@)
        # resizeObserver = new ResizeObserver ([r]) =>
        #   console.log r
        #   @geometry.resize r.contentRect.width, r.contentRect.height
        # resizeObserver.observe @domElement

      @domElement.style.display = 'flex'

      mkLayer = (name) =>
        layer = document.createElement 'div'
        layer.style.position = 'absolute'
        layer.style.margin   = 0
        layer.style.width    = '100%'
        layer.style.height   = '100%'
        layer.id = @domElement.id + '-layer-' + name
        @domElement.appendChild layer
        layer

      @domLayer   = mkLayer 'dom'
      @glLayer    = mkLayer 'gl'
      @statsLayer = mkLayer 'stats'

      @glLayer    . style.pointerEvents = 'none'
      @statsLayer . style.pointerEvents = 'none'

  refreshSize: () ->
    @geometry.resize @domElement.clientWidth, @domElement.clientHeight


  #FIXME: read note in usage place
  updateSizeSLOW: () ->
    dwidth  = @domElement.clientWidth
    dheight = @domElement.clientHeight
    if dwidth != @width || dheight != @height
      @geometry.resize @domElement.clientWidth, @domElement.clientHeight

  disableDOMLayerPointerEvents: () -> @domLayer.style.pointerEvents = 'none'
  enableDOMLayerPointerEvents : () -> @domLayer.style.pointerEvents = 'auto'


createCanvas = () ->
  document.createElementNS 'http://www.w3.org/1999/xhtml', 'canvas'



##################
### SceneModel ###
##################

class SceneModel extends Composable
  cons: (cfg) ->
    @_model      = new THREE.Scene
    @_camera     = null
    @_renderer   = null
    @configure cfg

  @getter 'domElement', -> @renderer.domElement

  setSize: (w,h) -> @renderer.setSize w,h

  render: (args...) ->
    @renderer.render @model, @camera.__glCamera, args...



#############
### Scene ###
#############

export class Scene extends Composable

  ### Initialization ###

  cons: (cfg) ->
    @mixin eventDispatcherMixin, @
    @_dom            = @mixin SceneDOM, cfg
    @_autoUpdate     = true
    @_camera         = new Camera
    modeCfg          = extend cfg, {camera: @_camera}
    @_symbolModel    = new SceneModel modeCfg
    @_domModel       = new SceneModel modeCfg
    @_symbolRegistry = new SymbolRegistry @_symbolModel.model
    @configure cfg
    @_creationTime   = Date.now()

    @initSymbolPointerBuffers()
    @initMouseBuffers()
    @_idScreenshotRequests = []

    @_stats = new Stats


  init: ->
    #TODO: make mixin initialization postponed to this moment!
    @symbolModel._renderer = @initWebGLRenderer()
    @domModel._renderer    = @initDomRenderer()
    @camera.adjustToScene @
    World.globalWorld.registerScene @
    @geometry.onResized = @onResized.bind(@)
    @geometry.onResized()
    if @onscreen
      @initSymbolPointerBuffers()
      @initMouseListeners()
      @_initDOM()
      @_initDebug()

    if @autoUpdate
      animationManager.addEveryDrawAnimation @update.bind(@)

  initWebGLRenderer: ->
    canvas               = createCanvas()
    canvas.width         = @width
    canvas.height        = @height
    canvas.style.display = 'block'
    renderer = new THREE.WebGLRenderer
      antialias : true
      alpha     : true
      canvas    : canvas
    renderer.setPixelRatio window.devicePixelRatio
    renderer.autoClear = false
    renderer

  _initDOM: () ->
    @dom.glLayer    . appendChild @symbolModel.renderer.domElement
    @dom.domLayer   . appendChild @domModel.renderer.domElement
    @dom.statsLayer . appendChild @stats.domElement

  _initDebug: () ->
    @addEventListener 'keydown', (event) =>
      trigger = event.altKey && event.ctrlKey
      if not trigger then return
      if (event.key >= '0') && (event.key <= '9')
        @_symbolRegistry.materials.uniforms.displayMode = parseInt(event.key)
      else if (event.key == '`')
        @_stats.toggle()
    #     Debug.getInspector().toggle()

  initDomRenderer  : -> new THREE.CSS3DRenderer
  initSymbolPointerBuffers : ->
    @_idBuffer = new Float32Array (4*@width*@height)
    @_idTarget = new THREE.WebGLRenderTarget @width, @height,
      type      : THREE.FloatType
      minFilter : THREE.NearestFilter
      magFilter : THREE.NearestFilter
      format    : THREE.RGBAFormat

   initMouseBuffers: () ->
     @_mouseIDBuffer      = new Float32Array 4
     @_lastTarget         = new SymbolTarget
     @_lastTarget.element = @
     @_screenMouse        = new THREE.Vector2
     @_mouse              = new THREE.Vector2
     @_mouseBaseEvent     = null

  initMouseListeners: () ->
    addCaptureListener = (name, f) =>
      @domElement.addEventListener name, f, true
    redirectCaptureListener = (name) =>
      addCaptureListener name, (e) => @lastTarget.dispatchEvent e
    redirectCaptureListener 'mousedown'
    redirectCaptureListener 'mouseup'
    redirectCaptureListener 'click'
    redirectCaptureListener 'dblclick'
    addCaptureListener      'mousemove', (e) =>
      @screenMouse.x = e.layerX
      @screenMouse.y = e.layerY
      campos = @camera.position
      @mouse.x = @screenMouse.x * campos.z + campos.x
      @mouse.y = @screenMouse.y * campos.z - campos.y
      # @mouse.x = (@screenMouse.x-@width/2 ) * campos.z + campos.x
      # @mouse.y = (@screenMouse.y-@height/2) * campos.z - campos.y
      @_mouseBaseEvent = e


  ### Callbacks ###

  onResized: () ->
    @initSymbolPointerBuffers()
    @symbolModel . setSize @width, @height
    @domModel    . setSize @width, @height
    @camera.adjustToScene @

  requestIDScreenshot: (callback) ->
    @idScreenshotRequests.push callback


  ### Utils ###

  visibleSpace  : -> [@visibleWidth(), @visibleHeight()]
  visibleWidth  : -> @width  * @camera.position.z
  visibleHeight : -> @height * @camera.position.z

  add: (a) -> a.addToScene @
  addSymbol: (s) -> @register(s).newInstance()

  addDOMSymbol: (s) ->
    inst = s.newInstance()
    @domModel.model.add inst.obj
    inst

  register: (s) ->
    @symbolRegistry.registerSymbol s

  update: -> @_stats.measure =>
    @camera.update @
    @symbolRegistry.materials.uniforms.zoom       = @camera.position.z
    @symbolRegistry.materials.uniforms.time       = Date.now() - @_beginTime
    @symbolRegistry.materials.uniforms.drawBuffer = DRAW_BUFFER.NORMAL
    @symbolModel.render()
    @domModel.render()
    if @onscreen then @handleMouse()

  handleMouse: ->
    @symbolRegistry.materials.uniforms.drawBuffer = DRAW_BUFFER.ID
    @symbolModel.render @idTarget, true
    @symbolModel.renderer.readRenderTargetPixels @idTarget, @screenMouse.x,
      @idTarget.height - @screenMouse.y, 1, 1, @_mouseIDBuffer
    if @idScreenshotRequests.length > 0
      @symbolModel.renderer.readRenderTargetPixels @idTarget, 0,0, @width,
        @height, @idBuffer
      for request in @idScreenshotRequests
        request @idBuffer
      @_idScreenshotRequests = []

    symbolFamilyID = @_mouseIDBuffer[0]
    symbolID       = @_mouseIDBuffer[1]
    shapeID        = @_mouseIDBuffer[2]

    ## Finding current SymbolTarget
    targetPath = new SymbolTargetPath symbolFamilyID, symbolID, shapeID
    if not (@_lastTarget.path.compare targetPath)
      target = null
      if (shapeID == 0)
        @enableDOMLayerPointerEvents()
        target = new SymbolTarget targetPath
        target.element = @
      else
        @disableDOMLayerPointerEvents()
        family         = @_symbolRegistry.lookupSymbolFamily symbolFamilyID
        if not family then return # wrong results when resizing scene!
        symbol         = family.lookupSymbol symbolID
        shapeDef       = family.definition.shape
        shapeDefTarget = symbol.lookupShapeDef shapeID
        target         = new SymbolTarget targetPath, symbol,
                                          shapeDef, shapeDefTarget
        target.element = target.discoverPointerEventTarget()

      ## Dispatching events
      targetChanged = target.element != @_lastTarget.element
      symbolChanged = (not (target.path.compareSymbol @_lastTarget.path)) &&
                      (target.element.type == Shape)
      if targetChanged || symbolChanged
        lastChain    = @_lastTarget.getParentChain()
        currentChain = target.getParentChain()
        mkMouseEvent = (name) => new MouseEvent name, @_mouseBaseEvent

        
        # Mouse OVER / OUT

        overEvent  = mkMouseEvent 'mouseover'
        outEvent   = mkMouseEvent 'mouseout'
        
        @_lastTarget.dispatchEvent outEvent
        target.dispatchEvent overEvent


        # Mouse ENTER / LEAVE 

        enterEvent = disableBubbling (mkMouseEvent 'mouseenter')
        leaveEvent = disableBubbling (mkMouseEvent 'mouseleave')

        j = 0
        for i in [0 ... currentChain.length]
          if lastChain[i] != currentChain[i]
            j = i
            break

        for i in [j ... currentChain.length]
          currentChain[i].dispatchEvent enterEvent

        for i in [j ... lastChain.length]
          lastChain[i].dispatchEvent leaveEvent


        @_lastTarget = target


export scene = Property.consAlias Scene



export class SymbolRegistry extends DisplayObject
  constructor: (model) ->
    super()
    @_model              = model
    @materials           = new MaterialStore
    @_symbolFamilyDefMap = new Map
    @_symbolFamilyIDMap  = new Map
    @variables           = @materials.uniforms
    @_symbolFamilyIDPool = new IdxPool 1

  registerSymbol: (comp) ->
    family = @_symbolFamilyDefMap.get comp
    if not family?
      id       = @_symbolFamilyIDPool.reserve()
      geometry = new SymbolGeometry comp._localVariables
      family   = new SymbolFamily id, comp, geometry
      @_symbolFamilyDefMap.set comp, family
      @_symbolFamilyIDMap.set  id  , family
      @materials.add comp.material
      @_model.add family._mesh
    family

  lookupSymbolFamily: (id) -> @_symbolFamilyIDMap.get id
