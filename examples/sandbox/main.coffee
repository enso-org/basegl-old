import {mat4} from 'gl-matrix'
import * as utils   from 'basegl/render/webgl'

import {Composable, fieldMixin}            from "basegl/object/Property"
import {DisplayObject, displayObjectMixin} from 'basegl/display/DisplayObject'
import {Vector}                            from "basegl/math/Vector"
import {logger}                            from 'basegl/debug/logger'
import * as basegl from 'basegl'
import {circle, glslShape, union, grow, negate, rect, quadraticCurve, path, plane}      from 'basegl/display/Shape'
import * as Color     from 'basegl/display/Color'
import * as Symbol from 'basegl/display/Symbol'

import * as Sprite from 'basegl/display/Sprite'





main = () ->

  canvas = document.getElementById("canvas")
  gl = canvas.getContext("webgl2")
  if (!gl) 
    return

  radToDeg = (r) ->
    return r * 180 / Math.PI
  

  degToRad = (d) ->
    return d * Math.PI / 180
  

  fieldOfViewRadians = degToRad(60)
  cameraAngleRadians = degToRad(0);

  fms = 0
  px  = 0

  drawScene = () ->
    radius = 200;

    utils.resizeCanvasToDisplaySize(gl.canvas);

    gl.viewport(0, 0, gl.canvas.width, gl.canvas.height);

    gl.clearColor(0, 0, 0, 0);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

    aspect = gl.canvas.clientWidth / gl.canvas.clientHeight;
    zNear = 1;
    zFar = 2000;
    projectionMatrix = mat4.create()
    mat4.perspective(projectionMatrix, fieldOfViewRadians, aspect, zNear, zFar)
    # projectionMatrix = m4.perspective(fieldOfViewRadians, aspect, zNear, zFar);

    fPosition = [radius, 0, 0];

    cameraMatrix = mat4.create()
    mat4.rotateY cameraMatrix, cameraMatrix, cameraAngleRadians
    mat4.translate cameraMatrix, cameraMatrix, [0, 20, 100+px*10]
    # cameraMatrix = m4.yRotation(cameraAngleRadians);
    # cameraMatrix = m4.translate(cameraMatrix, 0, 50, radius * 1.5);

    cameraPosition = [
      cameraMatrix[12],
      cameraMatrix[13],
      cameraMatrix[14],
    ];

    up = [0, 1, 0];

    # cameraMatrix = m4.lookAt(cameraPosition, fPosition, up);

    viewMatrix = mat4.invert cameraMatrix, cameraMatrix

    viewProjectionMatrix = mat4.create()
    mat4.multiply viewProjectionMatrix, projectionMatrix, viewMatrix

    Sprite.test(gl, viewProjectionMatrix)
    
    if fms < 10
      fms += 1
      px  += 10
      window.requestAnimationFrame(drawScene)

  

  drawScene()

  updateCameraAngle = (event, ui) ->
    cameraAngleRadians = degToRad(ui.value);
    drawScene();




main()



