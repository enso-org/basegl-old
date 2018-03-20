import {DisplayObject}   from "basegl/display/DisplayObject"



export class Camera extends DisplayObject
  constructor: (@fov=45) ->
    super()
    @__glCamera = new GLCamera @
    @position.z  = 1
    @_zoomFactor = 1

  @getter 'zoomFactor', -> @position.z

  adjustToScene: (scene) ->
    vFOV         = @fov * Math.PI / 180
    @_zoomFactor = scene.height / (2 * Math.tan(vFOV/2))
    @__glCamera.adjustToScene scene

  update: (scene) ->
    @__glCamera.position.x = @position.x + scene.width/2
    @__glCamera.position.y = @position.y + scene.height/2
    @__glCamera.position.z = @position.z * @_zoomFactor

  onTransformed: () ->
    super.onTransformed()
    @dispatchEvent (new Event 'move')

export class GLCamera extends THREE.PerspectiveCamera
  constructor: (@camera) ->
    super 45, 1, 0.1, 1000000

  adjustToScene: (scene) ->
    @aspect = scene.width / scene.height
    @updateProjectionMatrix()