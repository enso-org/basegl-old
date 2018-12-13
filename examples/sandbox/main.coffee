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

import vertexHeader   from 'basegl/lib/shader/component/vertexHeader'
import vertexBody     from 'basegl/lib/shader/component/vertexBody'
import fragmentHeader from 'basegl/lib/shader/component/fragmentHeader'
import fragmentRunner from 'basegl/lib/shader/component/fragmentRunner'
import fragment_lib   from 'basegl/lib/shader/sdf/sdf'


myShape = basegl.expr ->
  (circle(100) - circle(80)).move(100,100)

shader = myShape.toShader()
console.log shader.fragment 

main = () ->
  Sprite.test()
  # canvas = document.getElementById("canvas")
  # gl = canvas.getContext("webgl2")
  # if (!gl) 
  #   return


main()



