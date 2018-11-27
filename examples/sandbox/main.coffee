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

  drawScene = () ->
    radius = 200;

    utils.resizeCanvasToDisplaySize(gl.canvas);

    gl.viewport(0, 0, gl.canvas.width, gl.canvas.height);

    gl.clearColor(0, 0, 0, 0);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

    Sprite.test(gl)
    
  drawScene()

main()



