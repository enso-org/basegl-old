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
isCtrlPlus         = (e) -> e.key == "="  and e.shiftKey and (e.ctrlKey or e.metaKey)  # handle Cmd+"+" as well
isCtrlMinus        = (e) -> e.key == "-"  and (e.ctrlKey or e.metaKey)
isCtrlZero         = (e) -> e.key == "0"  and (e.ctrlKey or e.metaKey)


################
### Movement ###
################

# NOTE: this class is instantiated with each movement-related event.
# This means there will be some GC involved when there's a lot of
# objects created. However, it accounts for about 0.25% of program
# execution time, so not a bottleneck at all. Object creation
# is 0.02% of execution time.
class Movement
  constructor: ->
    @vec      = new Vector [0.0, 0.0, 0.0]
    @wheel    = false
    @applyDir = (a) -> a

  @ZOOM_SPEED: 4.0  # controls how much each "Ctrl + (+/-) zooms in/out
  @IDENTITY:   (a) -> a
  @NEGATE:     (a) -> a.negate()

  @zoomIn: ->
    movement = new Movement
    movement.vec.x = Movement.ZOOM_SPEED
    movement.wheel = true
    movement

  @zoomOut: ->
    movement = Movement.zoomIn()
    movement.applyDir = Movement.NEGATE
    movement

  @fromEvent: (event) ->
    wheel     = event.type == 'wheel'
    movementX = event.movementX || 0.0
    movementY = event.movementY || 0.0
    deltaX    = event.deltaX    || 0.0
    deltaY    = event.deltaY    || 0.0

    movement       = new Movement
    movement.vec.x = if wheel then deltaX else movementX
    movement.vec.y = if wheel then deltaY else movementY
    movement.wheel = wheel
    if (wheel and deltaY > 0) or (not wheel and movementX < movementY)
      movement.applyDir = Movement.NEGATE

    movement


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
    document.addEventListener          'keydown'    , @onKeyDown

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
    offsetX = event.offsetX || 0.0
    offsetY = event.offsetY || 0.0

    rx =   (offsetX / @scene.width  - 0.5)
    ry = - (offsetY / @scene.height - 0.5)

    [visibleWidth, visibleHeight] = @scene.visibleSpace()
    @clickPoint = new Vector [@scene.camera.position.x + rx * visibleWidth, @scene.camera.position.y + ry * visibleHeight, 0]
    @camPath    = @clickPoint.sub @scene.camera.position
    camPathNorm = @camPath.normalize()
    @camPath    = camPathNorm.div Math.abs(camPathNorm.z)

  _moveCamera: (movement) =>
    if @action == Navigator.ACTION.ZOOM
      movDeltaLen2 = movement.vec.length()
      z            = @scene.camera.position.z
      trans        = movement.applyDir (@camPath.mul (Math.abs z * movDeltaLen2 / 100))
      @desiredPos  = @desiredPos.add trans
      limit        = null
      if      (@desiredPos.z < @minDist) then limit = @minDist
      else if (@desiredPos.z > @maxDist) then limit = @maxDist
      if limit
        transNorm   = trans.normalize()
        transFix    = transNorm.div(transNorm.z).mul(limit-@desiredPos.z)
        @desiredPos = @desiredPos.add transFix

    else if @action == Navigator.ACTION.PAN
      [visibleWidth, visibleHeight] = @scene.visibleSpace()
      dir = if movement.wheel then -1.0 else 1.0
      @desiredPos.x -= movement.vec.x * (visibleWidth  / @scene.width)  * dir
      @desiredPos.y += movement.vec.y * (visibleHeight / @scene.height) * dir

  onMouseDown: (event) =>
    document.addEventListener 'mousemove', @onMouseMove
    @started = false

    if @eventIsZoom event
      @action = Navigator.ACTION.ZOOM
    else if @eventIsPan event
      @action = Navigator.ACTION.PAN
    else @action = null

    @_calcCameraPath event

  onMouseMove:   (event) => @_moveCamera (Movement.fromEvent event)
  onMouseUp:     (event) => document.removeEventListener 'mousemove', @onMouseMove
  onContextMenu: (event) => event.preventDefault()

  onWheel: (event) =>
    event.preventDefault()
    @_calcCameraPath event

    if event.ctrlKey
      # ctrl + wheel is how the trackpad-pinch is represented
      @action = Navigator.ACTION.ZOOM
    else
      # wheel only is two-finger scroll
      @action = Navigator.ACTION.PAN

    @_moveCamera (Movement.fromEvent event)

  onKeyDown: (event) =>
    ctrlMinus = isCtrlMinus event
    ctrlPlus  = isCtrlPlus  event
    ctrlZero  = isCtrlZero  event

    if ctrlMinus or ctrlPlus or ctrlZero
        event.preventDefault()
        @action = Navigator.ACTION.ZOOM

    if ctrlMinus
      @_calcCameraPath event
      @_moveCamera Movement.zoomOut()
    else if ctrlPlus
      @_calcCameraPath event
      @_moveCamera Movement.zoomIn()
    else if ctrlZero
      @desiredPos.z = 1.0
      @_moveCamera (new Movement)

  # Move the camera to a given point
  moveTo: (x, y) =>
    @desiredPos.x = x
    @desiredPos.y = y
    @_moveCamera (new Movement)
