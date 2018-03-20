
import * as Color     from 'basegl/display/Color'
import {POINTER_EVENTS}      from 'basegl/display/DisplayObject'
import {group}      from 'basegl/display/Symbol'
import * as Symbol from 'basegl/display/Symbol'
import {circle, glslShape, union, grow, negate, rect, quadraticCurve, path}      from 'basegl/display/Shape'
import {Navigator}      from 'basegl/navigation/Navigator'
import * as basegl from 'basegl'
import * as Shape     from 'basegl/display/Shape'

import * as Animation from 'basegl/animation/Animation'
import * as Easing    from 'basegl/animation/Easing'

# import {BoxSelector} from 'basegl/display/Selection'
import * as Font from 'basegl/display/text/Font'


import {animationManager} from 'basegl/animation/Manager'




#######################
### Node Definition ###
#######################

nodeRadius     = 30
gridElemOffset = 18
arrowOffset    = gridElemOffset + 2

nodeSelectionBorderMaxSize = 40

nodew = 300
nodeh = 700

white          = Color.rgb [1,1,1]
bg             = (Color.hsl [40,0.08,0.09]).toRGB()
selectionColor = bg.mix (Color.hsl [50, 1, 0.6]), 0.8
nodeBg         = bg.mix white, 0.04

nodeShape = basegl.expr ->
  border       = 0
  bodyWidth    = 300
  bodyHeight   = 600
  slope        = 20
  headerOffset = arrowOffset
  r1    = nodeRadius + border
  r2    = nodeRadius + headerOffset + slope - border
  dy    = slope
  dx    = Math.sqrt ((r1+r2)*(r1+r2) - dy*dy)
  angle = Math.atan(dy/dx)

  maskPlane     = glslShape("-sdf_halfplane(p, vec2(1.0,0.0));").moveX(dx)
  maskRect      = rect(r1+r2, r2 * Math.cos(-angle)).alignedTL.rotate(-angle)
  mask          = (maskRect - maskPlane).inside
  headerShape   = (circle(r1) + mask) - circle(r2).move(dx,dy)
  headerFill    = rect(r1*2, nodeRadius + headerOffset + 10).alignedTL.moveX(-r1)
  header        = (headerShape + headerFill).move(nodeRadius,nodeRadius).moveY(headerOffset+bodyHeight)

  body          = rect(bodyWidth + 2*border, bodyHeight + 2*border, 0, nodeRadius).alignedBL
  node          = (header + body).move(nodeSelectionBorderMaxSize,nodeSelectionBorderMaxSize)
  node          = node.fill nodeBg

  eye           = 'scaledEye.z'
  border        = node.grow(Math.pow(Math.clamp(eye*20.0, 0.0, 400.0),0.7)).grow(-1)

  sc            = selectionColor.copy()
  sc.a = 'selected'
  border        = border.fill sc

  border + node



### Utils ###

makeDraggable = (a) ->
  a.addEventListener 'mousedown', (e) ->
    if e.button != 0 then return
    s = basegl.world.activeScene
    fmove = (e) ->
      a.position.x += e.movementX * s.camera.zoomFactor
      a.position.y -= e.movementY * s.camera.zoomFactor
    window.addEventListener 'mousemove', fmove
    window.addEventListener 'mouseup', () =>
      window.removeEventListener 'mousemove', fmove

applySelectAnimation = (symbol, rev=false) ->
  if symbol.selectionAnimation?
  then symbol.selectionAnimation.reverse()
  else
    anim = Animation.create
      easing      : Easing.quadInOut
      duration    : 0.1
      onUpdate    : (v) -> symbol.variables.selected = v
      onCompleted :     -> delete symbol.selectionAnimation
    if rev then anim.inverse()
    anim.start()
    symbol.selectionAnimation = anim
    anim

selectedComponent = null
makeSelectable = (a) ->
  a.addEventListener 'mousedown', (e) ->
    console.log a.id
    if e.button != 0 then return
    symbol = e.symbol
    if selectedComponent == symbol then return
    applySelectAnimation symbol
    if selectedComponent
      applySelectAnimation selectedComponent, true
      selectedComponent.variables.zIndex = 1
    selectedComponent = symbol
    selectedComponent.variables.zIndex = -10

deselectAll = (e) =>
  if e.button != 0 then return
  if selectedComponent
    applySelectAnimation selectedComponent, true
    selectedComponent = null



### making the div ###
div = document.createElement( 'div' );
div.style.width = nodew + 'px';
div.style.height = '200px';
div.style.backgroundColor = '#FF0000';
div.id = 'examplebutton'

xid = 'SJOz3qjfQXU'
iframe = document.createElement( 'iframe' );
iframe.style.width = '480px';
iframe.style.height = '360px';
iframe.style.border = '0px';
iframe.src = [ "http://www.weather.gov/" ].join( '' );
# div.appendChild( iframe );

#
#
# container = document.getElementById 'basegl-scene-bottom'
#
# camera = new THREE.PerspectiveCamera( 50, window.innerWidth / window.innerHeight, 1, 5000 );
# camera.position.set( 500, 350, 750 );
#
# scene = new THREE.Scene()
#
# renderer = new THREE.CSS3DRenderer();
# renderer.setSize( window.innerWidth, window.innerHeight );
# renderer.domElement.style.position = 'absolute';
# renderer.domElement.style.top = 0;
# container.appendChild( renderer.domElement );
#
#
#
#
# object = new THREE.CSS3DObject( div );
# object.position.set( 400,200,0 );
# object.rotation.y = 0;
#
# scene.add object
#
# animate = () ->
#   renderer.render( scene, camera );
#   requestAnimationFrame( animate );
#
# animate()

main = () ->

  # Starting out, loading fonts, etc.
  basegl.fontManager.register 'DejaVuSansMono', 'fonts/DejaVuSansMono.ttf'
  await basegl.fontManager.load 'DejaVuSansMono'

  # Creating a new scene and placing it in HTML div
  scene = basegl.scene {domElement: 'scene'}

  # Adding navigation to scene
  controls = new Navigator scene


  # Defining shapes
  nodeDef = basegl.symbol nodeShape
  nodeDef.variables.selected = 0
  nodeDef.bbox.xy = [nodew + 2*nodeSelectionBorderMaxSize, nodeh + 2*nodeSelectionBorderMaxSize]


  vis  = basegl.symbol div
  vis1 = scene.add vis
  vis1.position.x = nodew/2 + nodeSelectionBorderMaxSize
  vis1.position.y = -80

  n1 = scene.add nodeDef
  n1.position.xy = [0, 0]
  n1.id = 1


  n2 = scene.add nodeDef
  n2.position.xy = [200, 0]
  n2.id = 2

  nn1 = group [n1,vis1]
  console.log nn1
  n3 = scene.add nodeDef
  n3.position.xy = [400, 0]
  n3.id = 3

  txtDef = basegl.text
    str: 'The quick brown fox \njumps over the lazy dog'
    fontFamily: 'DejaVuSansMono'
    size: 32

  txt1 = scene.add txtDef


  # str = 'The quick brown fox \njumps over the lazy dog'
  # txt = atlas.addText scene, str
  # txt.position.x += 100
  # txt.position.y += 100

  n1.variables.pointerEvents = 1
  n2.variables.pointerEvents = 1
  n3.variables.pointerEvents = 1

  n1.variables.zIndex = 1
  n2.variables.zIndex = 1
  n3.variables.zIndex = 1

  n1.addEventListener 'mouseover', (e) ->
    console.log "OVER NODE 1!"

  n2.addEventListener 'mouseover', (e) ->
    console.log "OVER NODE 2!"

  n3.addEventListener 'mouseover', (e) ->
    console.log "OVER NODE 3!"


  n1.addEventListener 'mouseout', (e) ->
    console.log "OUT NODE 1!"

  n2.addEventListener 'mouseout', (e) ->
    console.log "OUT NODE 2!"

  n3.addEventListener 'mouseout', (e) ->
    console.log "OUT NODE 3!"

  n1.style.childrenPointerEvents = POINTER_EVENTS.DISABLED

  makeDraggable nn1
  # makeDraggable n1
  makeDraggable n2
  makeDraggable n3

  makeSelectable n1
  makeSelectable n2
  makeSelectable n3

  scene.addEventListener 'mousedown', (e) -> deselectAll e


  scene.addEventListener 'keydown', (event) =>
    if (event.code == 'Backspace') || (event.code == 'Delete')
      selectedComponent?.dispose()
      selectedComponent = null
    else if (event.code == 'KeyN')
      newNode = scene.add nodeDef
      makeSelectable newNode
      makeDraggable  newNode

  # g1 = group [n1,n2,n3]
  # g1.position.x += 0

  # inst = 100000
  # for i in [0..(Math.sqrt inst)]
  #   for j in [0..(Math.sqrt inst)]
  #     n = scene.add node
  #     n.position.xy = [i*600,j*800]
  #     n.xxx = [i,j]
  #     makeDraggable n
  #
  #     # msg = "OVER NODE (#{i}, #{j})!"
  #     n.addEventListener 'mouseover', (e) ->
  #       console.log e.symbol.xxx

  # for i in [0..100]
  #   localComponent = new Component (selectionShape())
  #   localComponent.bbox.xy = [200,200]
  #   localComponent1 = scene.add localComponent
  #   localComponent1.position.xy = [i*100,0]

  #
  # selector = new BoxSelector scene, selector
  # selector.widget.variables.zIndex = 10










# console.log @_IDBuffer[4*(@width*(@height-@screenMouse.y) + @screenMouse.x)]

#
#
#
# if Detector.webgl
#   main()
# else
#   warning = Detector.getWebGLErrorMessage()
#   alert "WebGL not supported. #{warning}"

# ns = group [n1,n2]
# ns.rotation.z = 45
#

main()







#
# ################################
# ########## HS LOADING ##########
# ################################
#
#
# ajaxGetAsync = (url) ->
#   return new Promise (resolve, reject) ->
#     xhr = new XMLHttpRequest
#     xhr.timeout = 5000
#     xhr.onreadystatechange = (evt) ->
#       if (xhr.readyState == 4)
#         if(xhr.status == 200) then resolve xhr.responseText else reject (throw new Error xhr.statusText)
#     xhr.addEventListener "error", reject
#     xhr.open 'GET', url, true
#     xhr.send null
#
#
# fileNames = ['rts.js', 'lib.js', 'out.js', 'runmain.js']
# loader    = Promise.map fileNames, (fileName) -> return ajaxGetAsync fileName
# loader.catch (e) -> console.log "ERROR loading scripts!"
# loader.then (srcs) ->
#     modulesReveal = ("var #{m} = __shared__.modules.#{m};" for m of __shared__.modules).join ''
#     srcs.unshift modulesReveal
#     src = srcs.join '\n'
#     fn = new Function src
#     fn()
