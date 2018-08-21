import {Movement}  from "basegl/navigation/Movement"
import {Navigator} from "basegl/navigation/Navigator"


now = -> new Date().getTime()


export class EventInfo

  constructor: ->
    @isTouchPad = null
    @eventCount = 0
    @eventCountStart = null

  # Handy aliases for common event predicates
  isLeftClick:        (e) => e.button == 0
  isMiddleClick:      (e) => e.button == 1
  isRightClick:       (e) => e.button == 2
  isCtrlLeftClick:    (e) => e.button == 0 and e.ctrlKey
  isCtrlMiddleClick:  (e) => e.button == 1 and e.ctrlKey
  isCtrlRightClick:   (e) => e.button == 2 and e.ctrlKey
  isShiftLeftClick:   (e) => e.button == 0 and e.shiftKey
  isShiftMiddleClick: (e) => e.button == 1 and e.shiftKey
  isShiftRightClick:  (e) => e.button == 2 and e.shiftKey
  isCtrlPlus:         (e) => e.key == "="  and e.shiftKey and (e.ctrlKey or e.metaKey)  # handle Cmd+"+" as well
  isCtrlMinus:        (e) => e.key == "-"  and (e.ctrlKey or e.metaKey)
  isCtrlZero:         (e) => e.key == "0"  and (e.ctrlKey or e.metaKey)

  isTouchpadEvent: (e) =>
    return unless e.type == 'wheel'

    currTime = now()
    @eventCountStart = currTime if @eventCount == 0
    @eventCount++

    if currTime - @eventCountStart > 100
      @isTouchPad = @eventCount > 5
      @eventCount = 0

    return @isTouchPad


######################################################################
### EventReactor ###                                                 #
#                                                                    #
# The abstract class (template) for creating classes responsible for #
# listening to all the events and choosing appropriate reactions,    #
# for instance: to zoom the camera during the mousewheel scroll.     #
# The derived instances will issue the commands using a `Navigator`. #
######################################################################

export class EventReactor

  @ACTION:
    PAN:  'PAN'
    ZOOM: 'ZOOM'

  constructor: (@scene, @navigator) ->
    @navigator ?= new Navigator @scene
    @eventInfo = new EventInfo
    @action = null

  registerEvents: =>
    @scene.domElement.addEventListener 'contextmenu', @onContextMenu

  eventIsZoom: (event) => @eventInfo.isRightClick  event
  eventIsPan:  (event) => @eventInfo.isMiddleClick event

  onContextMenu: (event) => event.preventDefault()


##################################################################
### KeyboardMouseReactor ###                                     #
#                                                                #
# A concrete `EventReactor` instance for handling "traditional"  #
# mouse and keyboard event sources.                              #
##################################################################

export class KeyboardMouseReactor extends EventReactor

  @ACTION:
    PAN:  'PAN'
    ZOOM: 'ZOOM'

  constructor: (scene, navigator) ->
    super scene, navigator
    @eventInfo = new EventInfo
    @registerEvents()

  registerEvents: =>
    super()
    @scene.domElement.addEventListener 'mousedown'  , @onMouseDown
    document.addEventListener          'mouseup'    , @onMouseUp
    document.addEventListener          'wheel'      , @onWheel
    document.addEventListener          'keydown'    , @onKeyDown

  eventIsZoom: (event) => @eventInfo.isRightClick  event
  eventIsPan:  (event) => @eventInfo.isMiddleClick event

  onMouseDown: (event) =>
    document.addEventListener 'mousemove', @onMouseMove

    @action = if @eventIsZoom event
      EventReactor.ACTION.ZOOM
    else if @eventIsPan event
      EventReactor.ACTION.PAN
    else
      null

    @navigator.calcCameraPath (Movement.fromEvent event)

  onMouseMove: (event) =>
    movement = Movement.fromEvent event
    if @action == EventReactor.ACTION.ZOOM
      @navigator.zoom movement
    else if @action == EventReactor.ACTION.PAN
      @navigator.pan movement

  onMouseUp:     (event) => document.removeEventListener 'mousemove', @onMouseMove
  onContextMenu: (event) => event.preventDefault()

  onWheel: (event) =>
    event.preventDefault()
    isTouchPad = @eventInfo.isTouchpadEvent event
    console.log "isTouchPad: ", isTouchPad
    return if isTouchPad == null

    movement = Movement.fromEvent event
    @navigator.calcCameraPath movement

    if isTouchPad
      if event.ctrlKey
        # ctrl + wheel is how the trackpad-pinch is represented
        @navigator.zoom movement
      else
        # wheel only is two-finger scroll
        @navigator.pan movement
    else
      if event.ctrlKey
        @navigator.pan movement
      else
        @navigator.zoom movement

  onKeyDown: (event) =>
    ctrlMinus = @eventInfo.isCtrlMinus event
    ctrlPlus  = @eventInfo.isCtrlPlus  event
    ctrlZero  = @eventInfo.isCtrlZero  event

    if ctrlMinus or ctrlPlus or ctrlZero
        event.preventDefault()

    if ctrlMinus
      movement = Movement.zoomOut()
      @navigator.calcCameraPath movement
      @navigator.pan movement
    else if ctrlPlus
      movement = Movement.zoomIn()
      @navigator.calcCameraPath movement
      @navigator.pan movement
    else if ctrlZero
      @navigator.moveTo({ z: 1.0 })
