import {mat4} from 'gl-matrix'
import * as utils   from 'basegl/render/webgl'

import {Composable, fieldMixin}            from "basegl/object/Property"
import {DisplayObject, displayObjectMixin} from 'basegl/display/DisplayObject'
import {Vector}                            from "basegl/math/Vector"
import {logger}                            from 'basegl/debug/logger'
import * as basegl from 'basegl'
import {circle, glslShape, union, grow, negate, triangle, rect, quadraticCurve, path, plane, halfPlane}      from 'basegl/display/Shape'
import * as Shape  from 'basegl/display/Shape'
import * as Color  from 'basegl/display/Color'
import * as Symbol from 'basegl/display/Symbol'

import * as Sprite from 'basegl/display/Sprite'

import vertexHeader   from 'basegl/lib/shader/component/vertexHeader'
import vertexBody     from 'basegl/lib/shader/component/vertexBody'
import fragmentHeader from 'basegl/lib/shader/component/fragmentHeader'
import fragmentRunner from 'basegl/lib/shader/component/fragmentRunner'
import fragment_lib   from 'basegl/lib/shader/sdf/sdf'


myShape = basegl.expr ->
  plane().fill(Color.rgb([0,0.5,0,1]))
  # (circle(50) - circle(30).moveX(10)).fill(Color.rgb([0,0.5,0,1]))

myShape2 = basegl.expr ->
  # c = (circle(50) - circle(30).moveX(10)).fill(Color.rgb([1,0,0,1]))
  # b = circle(30).moveX(-30).fill(Color.rgb([0,0,1,0.5]))
  # c + b
  circle(50).alignx()
  # circle(50)
  # circle(50).fill(Color.rgb([1,0,0,1]))
  # Shape.rect(50,20)

main = () ->
  Sprite.test(myShape, myShape2)
  # canvas = document.getElementById("canvas")
  # gl = canvas.getContext("webgl2")
  # if (!gl) 
  #   return


main()



