import {Vector}           from "basegl/math/Vector"


##############################################################################
# ### Movement ###                                                           #
#                                                                            #
# The class encapsulating a notion of moving the camera.                     #
# It is a parameter given to the `Navigator` commands like `zoom` and `pan`. #
#                                                                            #
# NOTE: this class is instantiated with each movement-related event.         #
# This means there will be some GC involved when there's a lot of objects    #
# created. However, it accounts for about 0.25% of program execution time,   #
# so not a bottleneck at all. Object creation is 0.02% of execution time.    #
##############################################################################

export class Movement

  constructor: ->
    @vec      = new Vector [0.0, 0.0, 0.0]
    @offset   = { x: 0.0, y: 0.0 }
    @applyDir = (a) -> a

  @ZOOM_SPEED: 4.0  # controls how much each "Ctrl + (+/-) zooms in/out
  @IDENTITY:   (a) -> a
  @NEGATE:     (a) -> a.negate()
  @TYPE:
    ZOOM: 'ZOOM'
    PAN:  'PAN'

  @zoomIn: ->
    movement = new Movement
    movement.vec.x = Movement.ZOOM_SPEED
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

    movement = new Movement
    movement.offset = { x: event.offsetX, y: event.offsetY }
    movement.vec.x  = if wheel then -deltaX else movementX
    movement.vec.y  = if wheel then -deltaY else movementY
    if (wheel and deltaY > 0) or (not wheel and movementX < movementY)
      movement.applyDir = Movement.NEGATE

    movement
