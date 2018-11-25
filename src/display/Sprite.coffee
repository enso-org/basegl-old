import * as matrix2 from 'gl-matrix'
import {Program}   from 'basegl/render/webgl'

import {Composable, fieldMixin}            from "basegl/object/Property"
import * as Property           from "basegl/object/Property"
import {DisplayObject, displayObjectMixin} from 'basegl/display/DisplayObject'
import * as Matrix                       from 'gl-matrix'
import {Vector}                            from "basegl/math/Vector"
import {logger}                            from 'logger'
import * as basegl from 'basegl'
import {circle, glslShape, union, grow, negate, rect, quadraticCurve, path, plane}      from 'basegl/display/Shape'
import * as Color     from 'basegl/display/Color'
import * as Symbol from 'basegl/display/Symbol'
import {shallowCompare} from 'basegl/object/compare'
import * as Config from 'basegl/object/config'

import {vec2, vec3, vec4, mat2, mat3, mat4} from 'basegl/data/vector'
import * as Buffer          from 'basegl/data/buffer'
import * as Pool            from 'basegl/data/pool'
import * as GL              from 'basegl/lib/webgl/utils'
import * as EventDispatcher from 'basegl/event/dispatcher'
import * as Lazy            from 'basegl/object/lazy'
import * as Unique          from 'basegl/object/unique'
import * as Logged          from 'basegl/object/logged'
import * as Variable        from 'basegl/display/symbol/3D/geometry/variable'
import * as Geometry        from 'basegl/display/symbol/3D/geometry'
import * as Material        from 'basegl/display/symbol/3D/material'
import * as Mesh            from 'basegl/display/symbol/3D/mesh'

# import * as Benchmark from 'benchmark'

import _ from 'lodash';
import process from 'process';

benchmark = require('benchmark');
Benchmark = benchmark.runInContext({ _, process });
window.Benchmark = Benchmark;


#############
### UTILS ###
#############




# class Foo
#   @_nextID = 0
#   @getID: ->
#     id = @_nextID 
#     @_nextID += 1
#     id

#   constructor: () ->
#     @id = @constructor.getID()


# foo1 = new Foo
# foo2 = new Foo

# console.log foo1
# console.log foo2



### BENCHMARKS ###

# bench = ->
#   typedArrayRW = ->
#     arr = new Float32Array 1000
#     return
#       name: 'typedArrayRW'
#       fn: ->
#         for i in [1...1000]
#           arr[i] = arr[i-1]+1


#   bufferRW = ->
#     arr = new Float32Array 1000
#     arr = new Buffer arr
#     return
#       name: 'bufferRW'
#       fn: ->
#         for i in [1...1000]
#           arr.write i, (arr.read(i-1)+1)

#   suite = new Benchmark.Suite

#   suite
#     .add typedArrayRW()
#     .add bufferRW()
      
#     .on  'cycle', (event)  -> console.log(String(event.target))
#     .on  'complete',       -> console.log('Fastest is ' + this.filter('fastest').map('name'))
#     .run({ 'async': false })

# arr = new Float32Array 10
# for i in [1...10]
#   arr[i] = arr[i-1]+1
# console.log arr


# arr = new Float32Array 10
# arr = new Buffer arr
# for i in [1...10]
#   arr.write i, (arr.read(i-1)+1)
# console.log arr


# bench()






#######################
### WebGL constants ###
#######################

CTX = WebGLRenderingContext



webGL =
  usage:
    static      : CTX.STATIC_DRAW
    dynamic     : CTX.DYNAMIC_DRAW
    stream      : CTX.STREAM_DRAW
    staticRead  : CTX.STATIC_READ
    dynamicRead : CTX.DYNAMIC_READ
    streamRead  : CTX.STREAM_READ
    staticCopy  : CTX.STATIC_COPY
    dynamicCopy : CTX.DYNAMIC_COPY
    streamCopy  : CTX.STREAM_COPY












export test = (ctx, viewProjectionMatrix) ->


  # program = utils.createProgram(ctx,
  #     [vertexShaderSource, fragmentShaderSource])

  geo = new Geometry.create
    label: "Geo1"
    point:
      position: 
        usage : webGL.usage.static
        data  : [
          (vec3 -100,  100, 0),
          (vec3 -100, -100, 0),
          (vec3  100,  100, 0),
          (vec3  100, -100, 0)]
      uv: [
        # usage : usage.static
        # data  : [
          (vec2 0,1),
          (vec2 0,0),
          (vec2 1,1),
          (vec2 1,0)] 

      # color: 
      #   type: vec4
      #   data: new Float32Array [
      #     1,0,0,1,
      #     0,1,0,1,
      #     0,0,1,1,
      #     1,1,1,1]

      # color: [
      #   (vec4 1,0,0,1),
      #   (vec4 0,1,0,1),
      #   (vec4 0,0,1,1),
      #   (vec4 1,1,1,1)
      # ]

      # color: 
      #   type: vec4
      #   default: [1,0,0,1,0,1,0,1]
      
      # transform: [
      #   (mat4 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,100) ,
      #   (mat4 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0) ,
      #   (mat4 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0) ,
      #   (mat4 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0) ]
      
    instance:
      color: vec4
      color: [
        (vec4 1,0,0,1)] # , (vec4 0,1,0,1) ]
      # color: 
      #   data: vec4(1,0,0,1)
      #   default: [1,0,1]
      transform: [mat4(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-100), mat4()]
      # foo: [1,2]

    object:
      matrix: mat4

  bufferRegistry = new Variable.GPUAttributeRegistry ctx
  meshRegistry   = new Mesh.GPUMeshRegistry


  vertexShaderSource = '''
  void main() {
    gl_Position = matrix * v_position;
    gl_Position.x += v_transform[3][3];
  }
  '''

  fragmentShaderSource = '''
  out vec4 output_color;  
  void main() {
    output_color = color;
  }'''

  mat1 = new Material.Raw
    vertex   : vertexShaderSource
    fragment : fragmentShaderSource
    input:
      position  : vec4()
      transform : mat4()
      matrix    : mat4()
      color     : vec4 0,1,0,1
  mesh = Mesh.create geo, mat1

  m1 = new Mesh.GPUMesh ctx, bufferRegistry, mesh
  meshRegistry.add m1



  # console.log mat1.shader
  # mat1.writePointVariable 'position', (vec4 [0,0,0,0])
  # mat1.writePointVariable 'color', (vec4 [0,0,0,1])
  # mat1.writePointVariable 'uv', (vec2 [0,0])
  # mat1.writeObjectVariable 'matrix', (mat4 [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0])
  # mat1.writeOutputVariable 'color', (vec4 [0,0,0,0])
  # console.log mat1.shader.vertex
  # console.log mat1.shader.fragment

  logger.group "FRAME 1", =>
    # geo.point.data.position.read(0)[0] = 7
    # console.log geo.instance.data.color
    # geo.instance.addAttribute 'color', 
    #   type: vec4
    #   default: vec4(1,0,0,1)
    # geo.instance.data.color.read(0).rgba = [1,0,0,1]
    # geo.instance.data.color.read(1).rgba = [0,1,0,1]
    meshRegistry.update()
    bufferRegistry.update()
    # meshRegistry.update()
  
  # logger.group "FRAME 2", =>
    # geo.point.data.position.read(0)[0] = 7
  #   geo.point.data.position.read(0)[0] = 7
  #   geo.point.data.position.read(0)[1] = 7
  #   bufferRegistry.update()
  #   # meshRegistry.update()

  # logger.group "FRAME 3", =>
  #   # geo.point.data.position.read(1)[0] = 8
  #   # geo.point.data.uv.read(1)[0] = 8
  #   # geo.instance.add({color: vec4(0,0,1,1)})
  #   geo.instance.add({color: vec4(0,1,0,1), transform:mat4(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,10)})
  #   # geo.instance.add({color: vec4(0,0,0,1)})
  #   # geo.instance.data.color.read(0)[0] = 0.7
  #   bufferRegistry.update()
  #   # meshRegistry.update()

  # logger.group "FRAME 4", =>
  #   bufferRegistry.update()
  #   # meshRegistry.update()


  m1.draw(viewProjectionMatrix)
  