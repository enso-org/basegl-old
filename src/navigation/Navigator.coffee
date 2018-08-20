import {Vector}           from "basegl/math/Vector"
import {animationManager} from "basegl/animation/Manager"
import {Movement}         from "basegl/navigation/Movement"


#############################################################################
### Navigator ###                                                           #
#                                                                           #
# The utility for moving (and animating) the camera. Supports commands such #
# as `zoom`, `pan` and `moveTo`                                             #
#############################################################################

export class Navigator

  constructor: (@scene) ->
    @zoomFactor   = 1
    @drag         = 10
    @springCoeff  = 1.5
    @mass         = 20
    @minDist      = 0.1
    @maxDist      = 10
    @maxVel       = 1
    @minVel       = 0.001

    @vel          = new Vector
    @desiredPos   = Vector.fromXYZ @scene.camera.position
    @campos       = null

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

  calcCameraPath: (movement) =>
    rx =   (movement.offset.x / @scene.width  - 0.5)
    ry = - (movement.offset.y / @scene.height - 0.5)

    [visibleWidth, visibleHeight] = @scene.visibleSpace()
    clickPointX = @scene.camera.position.x + rx * visibleWidth
    clickPointY = @scene.camera.position.y + ry * visibleHeight
    clickPoint  = new Vector [ clickPointX, clickPointY, 0]
    @camPath    = clickPoint.sub @scene.camera.position
    camPathNorm = @camPath.normalize()
    @camPath    = camPathNorm.div Math.abs(camPathNorm.z)

  zoom: (movement) =>
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

  pan: (movement) =>
    [visibleWidth, visibleHeight] = @scene.visibleSpace()
    @desiredPos.x -= movement.vec.x * (visibleWidth  / @scene.width)
    @desiredPos.y += movement.vec.y * (visibleHeight / @scene.height)

  # Move the camera to a given point.
  moveTo: (coords) =>
    defCoords = { x: null, y: null, z: null }
    coords2   = Object.assign(defCoords, coords)
    @desiredPos.x = coords2.x if coords2.x?
    @desiredPos.y = coords2.y if coords2.y?
    @desiredPos.z = coords2.z if coords2.z?

    @pan (new Movement)
