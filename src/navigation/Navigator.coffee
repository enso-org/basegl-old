import {Vector}           from "basegl/math/Vector"
import {animationManager} from "basegl/animation/Manager"


# Handy aliases for common event predicates
isLeftClick        = (e) -> e.button == 0
isMiddleClick      = (e) -> e.button == 1
isRightClick       = (e) -> e.button == 2
isCtrlLeftClick    = (e) -> e.button == 0 and e.ctrlKey
isCtrlMiddleClick  = (e) -> e.button == 1 and e.ctrlKey
isCtrlRightClick   = (e) -> e.button == 2 and e.ctrlKey
isShiftLeftClick   = (e) -> e.button == 0 and e.shiftKey
isShiftMiddleClick = (e) -> e.button == 1 and e.shiftKey
isShiftRightClick  = (e) -> e.button == 2 and e.shiftKey


#################
### Navigator ###
#################

export class Navigator
  @ACTION:
    PAN : 'PAN'
    ZOOM: 'ZOOM'

  constructor: (@scene, actions={ isPan:  isMiddleClick
                                , isZoom: isRightClick
                                }) ->
    @zoomFactor   = 1
    @drag         = 10
    @springCoeff  = 1.5
    @mass         = 20
    @minDist      = 0.1
    @maxDist      = 10
    @maxVel       = 1
    @minVel       = 0.001

    @vel          = new Vector
    @acc          = new Vector
    @desiredPos   = Vector.fromXYZ @scene.camera.position
    @campos       = null
    @action       = null
    @started      = false
    @eventIsPan   = actions.isPan
    @eventIsZoom  = actions.isZoom

    @scene.domElement.addEventListener 'mousedown'  , @onMouseDown
    @scene.domElement.addEventListener 'contextmenu', @onContextMenu
    document.addEventListener          'mouseup'    , @onMouseUp
    document.addEventListener          'wheel'      , @onWheel

    animationManager.addConstantRateAnimation @.onEveryFrame


  onEveryFrame: () =>
    camDelta    = @desiredPos.sub @scene.camera.position
    camDeltaLen = camDelta.length()
    return if camDeltaLen == 0

    forceVal    = camDeltaLen * @springCoeff
    force       = camDelta.normalize().mul forceVal
    force.z     = camDelta.z * @springCoeff
    acc         = force.div @mass

    @vel.addMut acc
    newVelVal = @vel.length()

    if newVelVal < @minVel
      @vel.zeroMut()
      @scene.camera.position.x = @desiredPos.x
      @scene.camera.position.y = @desiredPos.y
      @scene.camera.position.z = @desiredPos.z
    else
      @vel = @vel.normalize().mul newVelVal
      @scene.camera.position.x += @vel.x
      @scene.camera.position.y += @vel.y
      @scene.camera.position.z += @vel.z

      if newVelVal != 0
        @vel = @vel.div (1 + @drag * newVelVal)


  _calcCameraPath: (event) =>
    @campos = Vector.fromXYZ @scene.camera.position    

    rx =   (event.offsetX / @scene.width  - 0.5)
    ry = - (event.offsetY / @scene.height - 0.5)

    [visibleWidth, visibleHeight] = @scene.visibleSpace()
    @clickPoint = new Vector [@scene.camera.position.x + rx * visibleWidth, @scene.camera.position.y + ry * visibleHeight, 0]
    @camPath    = @clickPoint.sub @scene.camera.position
    camPathNorm = @camPath.normalize()
    @camPath    = camPathNorm.div Math.abs(camPathNorm.z)

  _moveCamera: (event, wheel=false) =>
    if wheel
      movement = new Vector [event.deltaX, event.deltaY, 0]
    else
      movement = new Vector [event.movementX, event.movementY, 0]

    applyDir = (a) ->
      if wheel
        if event.deltaY > 0 then a.negate() else a
      else
        if event.movementX < event.movementY then a.negate() else a

    if @action == Navigator.ACTION.ZOOM
      movementDeltaLen2 = movement.length()
      trans             = applyDir (@camPath.mul (Math.abs (@scene.camera.position.z) * movementDeltaLen2 / 100))
      @desiredPos       = @desiredPos.add trans
      limit             = null
      if      (@desiredPos.z < @minDist) then limit = @minDist
      else if (@desiredPos.z > @maxDist) then limit = @maxDist
      if limit
        transNorm   = trans.normalize()
        transFix    = transNorm.div(transNorm.z).mul(limit-@desiredPos.z)
        @desiredPos = @desiredPos.add transFix

    else if @action == Navigator.ACTION.PAN
      [visibleWidth, visibleHeight] = @scene.visibleSpace()
      dir = if wheel then -1.0 else 1.0
      @desiredPos.x -= movement.x * (visibleWidth  / @scene.width)  * dir
      @desiredPos.y += movement.y * (visibleHeight / @scene.height) * dir

  onMouseDown: (event) =>
    document.addEventListener 'mousemove', @onMouseMove
    @started = false

    if @eventIsZoom event
      @action = Navigator.ACTION.ZOOM
    else if @eventIsPan event
      @action = Navigator.ACTION.PAN
    else @action = null

    @_calcCameraPath event

  onMouseMove:   (event) => @_moveCamera event
  onMouseUp:     (event) => document.removeEventListener 'mousemove', @onMouseMove
  onContextMenu: (event) => event.preventDefault()

  onWheel: (event) =>
    event.preventDefault();
    @_calcCameraPath event

    if event.ctrlKey
      # ctrl + wheel is how the trackpad-pinch is represented
      @action = Navigator.ACTION.ZOOM
    else
      # wheel only is two-finger scroll
      @action = Navigator.ACTION.PAN

    @_moveCamera(event, wheel=true)