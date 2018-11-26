import * as Config   from 'basegl/object/config'
import * as Variable from 'basegl/display/symbol/3D/geometry/variable'
import * as Geometry from 'basegl/display/symbol/3D/geometry'
import * as Material from 'basegl/display/symbol/3D/material'
import * as Mesh     from 'basegl/display/symbol/3D/mesh'
import * as Lazy     from 'basegl/object/lazy'
import * as Property from 'basegl/object/Property'

import {logger}                             from 'logger'
import {vec2, vec3, vec4, mat2, mat3, mat4} from 'basegl/data/vector'
import * as _ from 'lodash'



import * as Display from 'basegl/display/object'


export test2 = (ctx, viewProjectionMatrix) ->

  geo = Geometry.rectangle
    label    : "Geo1"
    width    : 200
    height   : 200
    instance :
      transform: [mat4(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-100), mat4()]
    object:
      matrix: mat4
      

  # geo = Geometry.create
  #   label: "Geo1"
  #   point:
  #     position: 
  #       usage : Variable.usage.static
  #       data  : [
  #         (vec3 -100,  100, 0),
  #         (vec3 -100, -100, 0),
  #         (vec3  100,  100, 0),
  #         (vec3  100, -100, 0)]
  #     uv: [
  #       # usage : usage.static
  #       # data  : [
  #         (vec2 0,1),
  #         (vec2 0,0),
  #         (vec2 1,1),
  #         (vec2 1,0)] 

  #     # color: 
  #     #   type: vec4
  #     #   data: new Float32Array [
  #     #     1,0,0,1,
  #     #     0,1,0,1,
  #     #     0,0,1,1,
  #     #     1,1,1,1]

  #     # color: [
  #     #   (vec4 1,0,0,1),
  #     #   (vec4 0,1,0,1),
  #     #   (vec4 0,0,1,1),
  #     #   (vec4 1,1,1,1)
  #     # ]

  #     # color: 
  #     #   type: vec4
  #     #   default: [1,0,0,1,0,1,0,1]
      
  #     # transform: [
  #     #   (mat4 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,100) ,
  #     #   (mat4 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0) ,
  #     #   (mat4 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0) ,
  #     #   (mat4 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0) ]
      
  #   instance:
  #   #   # color: vec4
  #   #   # color: [
  #   #   #   (vec4 1,0,0,1)] # , (vec4 0,1,0,1) ]
  #   #   # color: 
  #   #   #   data: vec4(1,0,0,1)
  #   #   #   default: [1,0,1]
  #     transform: [mat4(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-100), mat4()]
  #     # foo: [1,2]

  #   object:
  #     matrix: mat4


  attrRegistry = new Variable.GPUAttributeRegistry ctx
  meshRegistry = new Mesh.GPUMeshRegistry


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

  fragmentShaderSource2 = '''
  out vec4 output_color;  
  void main() {
    output_color = vec4(0,1,0,1);
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

  m1 = new Mesh.GPUMesh ctx, attrRegistry, mesh
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
    geo.instance.addAttribute 'color', 
      type: vec4
      default: vec4(1,0,0,1)
    # mat1.fragment = fragmentShaderSource2
    meshRegistry.update()
    attrRegistry.update()
    # meshRegistry.update()
  
  logger.group "FRAME 2", =>
    geo.instance.data.color.read(0).rgba = [1,1,0,1]
    geo.instance.data.color.read(1).rgba = [0,1,0,1]
    # geo.point.data.position.read(0)[0] = 7
  #   geo.point.data.position.read(0)[0] = 7
  #   geo.point.data.position.read(0)[1] = 7
    attrRegistry.update()
    meshRegistry.update()

  logger.group "FRAME 3", =>
  #   # geo.point.data.position.read(1)[0] = 8
  #   # geo.point.data.uv.read(1)[0] = 8
  #   # geo.instance.add({color: vec4(0,0,1,1)})
  #   geo.instance.add({color: vec4(0,1,0,1), transform:mat4(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,10)})
  #   # geo.instance.add({color: vec4(0,0,0,1)})
  #   # geo.instance.data.color.read(0)[0] = 0.7
    attrRegistry.update()
    meshRegistry.update()

  # logger.group "FRAME 4", =>
  #   attrRegistry.update()
  #   # meshRegistry.update()


  m1.draw(viewProjectionMatrix)
  

# console.log "---"





# class Base
#   @generateAccessors()
#   constructor: ->
#     @_field1 = 7

#   fn1: -> @_field1 += 1


# class C1
#   @mixin Base
#   constructor: ->
#     @mixins.constructor()

# console.log "^^^"
# console.log ""

# class C2
#   constructor: ->
#     @_base = new Base
    
#   @getter 'field1', -> @_base.field1 
#   @getter 'fn1',    -> @_base.fn1.bind @_base 


# # C1 = eval "
# # var C1;

# # C1 = (function() {
# #   class C1 {
# #     constructor() {
# #       this._base = new Base;
# #     }

# #   };

# #   C1.getter('field1', function() {
# #     return this._base.field1;
# #   });

# #   C1.getter('fn1', function() {
# #     return this._base.fn1.bind(this._base);
# #   });

# #   return C1;

# # }).call(this);
# # "

# window.C1 = C1
# window.c1 = new C1
# console.log c1
# console.log c1.field1
# c1.fn1()
# console.log c1.field1

# console.log "---"

# window.c2 = new C2
# console.log c2
# console.log c2.field1
# c2.fn1()
# console.log c2.field1



# # console.log C1.prototype.constructor


# t1 = performance.now()
# s  = 0
# for i in [1..10000000] by 1 
#   s += c2.field1
#   # c2.fn1()
# t2 = performance.now()
# console.log "C2", (t2-t1)


# t1 = performance.now()
# s  = 0
# for i in [1..10000000] by 1 
#   s += c1.field1
#   # c1.fn1()
# t2 = performance.now()
# console.log "C1", (t2-t1)

# t1 = performance.now()
# s  = 0
# for i in [1..10000000] by 1 
#   s += c2.field1
#   # c2.fn1()
# t2 = performance.now()
# console.log "C2", (t2-t1)


# t1 = performance.now()
# s  = 0
# for i in [1..10000000] by 1 
#   s += c1.field1
#   # c1.fn1()
# t2 = performance.now()
# console.log "C1", (t2-t1)

# t1 = performance.now()
# s  = 0
# for i in [1..10000000] by 1 
#   s += c2.field1
#   # c2.fn1()
# t2 = performance.now()
# console.log "C2", (t2-t1)

# t1 = performance.now()
# s  = 0
# for i in [1..10000000] by 1 
#   s += c1.field1
#   # c1.fn1()
# t2 = performance.now()
# console.log "C1", (t2-t1)

# t1 = performance.now()
# s  = 0
# for i in [1..10000000] by 1 
#   s += c2.field1
#   # c2.fn1()
# t2 = performance.now()
# console.log "C2", (t2-t1)


# t1 = performance.now()
# s  = 0
# for i in [1..10000000] by 1 
#   s += c1.field1
#   # c1.fn1()
# t2 = performance.now()
# console.log "C1", (t2-t1)

# t1 = performance.now()
# s  = 0
# for i in [1..10000000] by 1 
#   s += c2.field1
#   # c2.fn1()
# t2 = performance.now()
# console.log "C2", (t2-t1)


# t1 = performance.now()
# s  = 0
# for i in [1..10000000] by 1 
#   s += c1.field1
#   # c1.fn1()
# t2 = performance.now()
# console.log "C1", (t2-t1)

# t1 = performance.now()
# s  = 0
# for i in [1..10000000] by 1 
#   s += c2.field1
#   # c2.fn1()
# t2 = performance.now()
# console.log "C2", (t2-t1)

# throw "!"


# class Camera
#   @mixin Lazy.Object
#   constructor: (cfg={}) ->
#     @_fov = cfg.fov || 60
#     @mixins.constructor()

# class Camera2
#   constructor: (cfg={}) ->
#     @_fov    = cfg.fov || 60
#     @_object = new Lazy.Object

#   @getter 'dirty', -> @_object.dirty
#   @setter 'dirty', (v) -> @_object.dirty = v

# class Camera3 extends Lazy.Object
#   constructor: (cfg={}) ->
#     super cfg
#     @_fov    = cfg.fov || 60
#     @_object = new Lazy.Object


# class TT
#   @mixin Camera
#   constructor: (cfg) ->
#     @mixins.constructor()

# console.warn "Mk tt1"
# tt1 = new TT 
# console.warn "Mk tt2"
# tt2 = new TT
# console.warn "---"

# window.tt1 = tt1 
# window.tt2 = tt2


# a = new Camera
# console.log "---"
# b = new Camera
# console.log "---"

# window.cam = a

# console.log a
# console.log b




# t1 = performance.now()
# for i in [1..100000] by 1 
#   b = new Camera2
#   b.dirty.set()
#   b.dirty.unset()
# t2 = performance.now()
# console.log "C2", (t2-t1)

# t1 = performance.now()
# for i in [1..100000] by 1 
#   b = new Camera3
#   b.dirty.set()
#   b.dirty.unset()
# t2 = performance.now()
# console.log "C3", (t2-t1)

# t1 = performance.now()
# for i in [1..100000] by 1 
#   a = new Camera
#   a.dirty.set()
#   a.dirty.unset()
# t2 = performance.now()
# console.log "C1", (t2-t1)


# throw "!"


export test = (ctx, viewProjectionMatrix) ->

  geo = Geometry.rectangle
    label    : "Geo1"
    width    : 200
    height   : 200
    instance :
      transform: [mat4(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-100), mat4()]
    object:
      matrix: mat4
      

  attrRegistry = new Variable.GPUAttributeRegistry ctx
  meshRegistry = new Mesh.GPUMeshRegistry


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

  fragmentShaderSource2 = '''
  out vec4 output_color;  
  void main() {
    output_color = vec4(0,1,0,1);
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

  m1 = new Mesh.GPUMesh ctx, attrRegistry, mesh
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
    geo.instance.addAttribute 'color', 
      type: vec4
      default: vec4(1,0,0,1)
    # mat1.fragment = fragmentShaderSource2
    meshRegistry.update()
    attrRegistry.update()
    # meshRegistry.update()
  
  logger.group "FRAME 2", =>
    geo.instance.data.color.read(0).rgba = [1,1,0,1]
    geo.instance.data.color.read(1).rgba = [0,1,0,1]
    # geo.point.data.position.read(0)[0] = 7
  #   geo.point.data.position.read(0)[0] = 7
  #   geo.point.data.position.read(0)[1] = 7
    attrRegistry.update()
    meshRegistry.update()

  logger.group "FRAME 3", =>
  #   # geo.point.data.position.read(1)[0] = 8
  #   # geo.point.data.uv.read(1)[0] = 8
  #   # geo.instance.add({color: vec4(0,0,1,1)})
  #   geo.instance.add({color: vec4(0,1,0,1), transform:mat4(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,10)})
  #   # geo.instance.add({color: vec4(0,0,0,1)})
  #   # geo.instance.data.color.read(0)[0] = 0.7
    attrRegistry.update()
    meshRegistry.update()

  # logger.group "FRAME 4", =>
  #   attrRegistry.update()
  #   # meshRegistry.update()


  m1.draw(viewProjectionMatrix)
  


# class Sprite
#   constructor: ->
#     @_geometry = 


