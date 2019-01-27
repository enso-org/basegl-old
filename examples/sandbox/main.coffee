import {mat4} from 'gl-matrix'
import * as utils   from 'basegl/render/webgl'

import {Composable, fieldMixin}            from "basegl/object/Property"
import {DisplayObject, displayObjectMixin} from 'basegl/display/DisplayObject'
import {Vector}                            from "basegl/math/Vector"
import {logger}                            from 'basegl/debug/logger'
import * as basegl from 'basegl'
import {circle, glslShape, union, grow, negate, triangle, rectangle, quadraticCurve, path, plane, halfPlane}      from 'basegl/display/Shape'
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
  # a = circle(50).moveY(50)
  # b = circle(50)
  # a = rectangle(100,150).rotate(Math.PI/10).alignx();
  # a = rectangle(100,150).moveX(-10).rotate(Math.PI/10).grow(30).alignx();
  # a = rectangle(60,100).moveX(-10).rotate(Math.PI/10).grow(20).alignTR();
  
  # a = circle(60) - rectangle(80,80).grow(11).rotate(Math.PI/4).moveX(60)
  # # b = rectangle(10,200).moveX(5);
  # a + c
  # c = rectangle(200,10).moveY(-5);
  # a = circle(60) + rectangle(80,80).grow(11).rotate(Math.PI/4).moveX(60)
  # a = a.rotate(-Math.PI/10).moveX(-30).align()
  # a + c
  rectangle(20,50) # s.fill(Color.rgb([1,0,0,1]))
  # Shape.rect(50,20)

main = () ->
  Sprite.test(myShape, myShape2)
  # canvas = document.getElementById("canvas")
  # gl = canvas.getContext("webgl2")
  # if (!gl) 
  #   return



main()



