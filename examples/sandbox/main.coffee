import * as matrix2 from 'gl-matrix'
import * as utils   from 'basegl/render/webgl'

import {Composable, fieldMixin} from "basegl/object/Property"
import {DisplayObject, displayObjectMixin} from 'basegl/display/DisplayObject'
import {mat4, vec4}                   from 'gl-matrix'


withVAO = (gl, vao, f) -> 
  gl.bindVertexArray(vao)
  out = f()
  gl.bindVertexArray(null)
  out


withBuffer = (gl, type, buffer, f) -> 
  gl.bindBuffer(type, buffer)
  out = f()
  gl.bindBuffer(type, null)
  out

withArrayBuffer = (gl, buffer, f) ->
  withBuffer gl, gl.ARRAY_BUFFER, buffer, f 
  
arrayBufferSubData = (gl, buffer, dstByteOffset, srcData, srcOffset, length) ->
  withArrayBuffer gl, buffer, =>
    gl.bufferSubData(gl.ARRAY_BUFFER, dstByteOffset, srcData, srcOffset, length)
      

class Pool 
  constructor: (@size) -> 
    @free      = []
    @nextIndex = 0

  reserve: () ->
    n = @free.shift()
    if n != undefined      then return n
    if @nextIndex == @size then return undefined
    n = @nextIndex
    @nextIndex += 1
    n

  dirtySize: () -> @nextIndex

  free: (n) ->
    @free.push(n)


applyDef = (cfg, defCfg) ->
  if not cfg? then return defCfg
  for key of defCfg
    if cfg[key] == undefined
      cfg[key] = defCfg[key]


class Sprite extends Composable
  cons: (cfg) -> 
    @mixin displayObjectMixin, [], cfg
    @size    = {x: 100, y: 100}
    @_id     = null
    @_buffer = null
    @configure cfg

    @_displayObject.onTransformed = () =>
      @_buffer.markDirty @


  onTransformed: () -> 
    console.log "dupa"

# class Sprite extends DisplayObject
#   cons: (cfg) -> 
#     super []
#     # @mixin displayObjectMixin, [], cfg
#     @size    = {x: 100, y: 100}
#     @_id     = null
#     @_buffer = null
#     # @configure cfg


#   onTransformed: () ->
#     console.log "!!!"
#     super()
    


class SpriteBuffer
  constructor: (@_gl, @_program, @_variables) ->
    @_SPRITE_VTX_COUNT = 6
    @_ixPool           = new Pool 100
    @_vao = @_gl.createVertexArray()

    @_locs = @_program.lookupVariables @_variables  

    @__dirty = []

    @_buffers = {}

    withVAO @_gl, @_vao, =>
      positionBuffer = @_gl.createBuffer()
      @_gl.bindBuffer(@_gl.ARRAY_BUFFER, positionBuffer)

      positions = new Float32Array(@_SPRITE_VTX_COUNT * @_ixPool.size) 
      
      @_buffers.position = 
        js: positions
        gl: positionBuffer
      
      positions[0]  = 0
      positions[1]  = 0
      positions[2]  = 0
      positions[3]  = 0
      positions[4]  = 10
      positions[5]  = 0
      positions[6]  = 10
      positions[7]  = 0
      positions[8]  = 0
      positions[9]  = 0
      positions[10] = 10
      positions[11] = 0
      positions[12] = 10
      positions[13] = 10
      positions[14] = 0
      positions[15] = 10
      positions[16] = 0
      positions[17] = 0

      @_gl.bufferData(@_gl.ARRAY_BUFFER, positions, @_gl.DYNAMIC_DRAW)

      @_gl.enableVertexAttribArray(@_locs.attribute.position)

      size = 3          # 3 components per iteration
      type = @_gl.FLOAT   # the data is 32bit floats
      normalize = false # don't normalize the data
      stride = 0        # 0 = move forward size * sizeof(type) each iteration to get the next position
      offset = 0        # start at the beginning of the buffer
      @_gl.vertexAttribPointer(
          @_locs.attribute.position, size, type, normalize, stride, offset)



      colorBuffer = @_gl.createBuffer()
      withArrayBuffer @_gl, colorBuffer, =>
        # @_gl.bindBuffer(@_gl.ARRAY_BUFFER, colorBuffer)
        
        # withArrayBuffer = (gl, buffer, f) ->
        #   withBuffer gl, gl.ARRAY_BUFFER, buffer, f 

        #   withBuffer = (gl, type, buffer, f) -> 
        #   gl.bindBuffer(type, buffer)
        #   out = f()
        #   gl.bindBuffer(type, 0)
        #   out

        @_gl.bufferData( @_gl.ARRAY_BUFFER,
          new Uint8Array(@_SPRITE_VTX_COUNT * @_ixPool.size),
          @_gl.DYNAMIC_DRAW)
          #     # left column front
          #   200,  70, 120,
          #   200,  70, 120,
          #   200,  70, 120,
          #   200,  70, 120,
          #   200,  70, 120,
          #   200,  70, 120,

          # ]),
        

        # Turn on the attribute
        @_gl.enableVertexAttribArray(@_locs.attribute.color)

        # Tell the attribute how to get data out of colorBuffer (ARRAY_BUFFER)
        size = 3          # 3 components per iteration
        type = @_gl.UNSIGNED_BYTE   # the data is 8bit unsigned bytes
        normalize = true  # convert from 0-255 to 0.0-1.0
        stride = 0        # 0 = move forward size * sizeof(type) each iteration to get the next color
        offset = 0        # start at the beginning of the buffer
        @_gl.vertexAttribPointer(
            @_locs.attribute.color, size, type, normalize, stride, offset)

      # TODO REMOVE
      @_ixPool.reserve()

  # markDirty: (ix) ->
  #   if @__dirtyRange == null 
  #     @__dirtyRange = {min:ix, max:ix}
  #   else
  #     if      ix < @__dirtyRange.min then @__dirtyRange.min = ix
  #     else if ix > @__dirtyRange.max then @__dirtyRange.max = ix

  markDirty: (sprite) ->
    @__dirty.push(sprite)

  draw: (viewProjectionMatrix) ->
    @render() 
    withVAO @_gl, @_vao, =>
      @_gl.uniformMatrix4fv(@_locs.uniform.matrix, false, viewProjectionMatrix)
      vtxCount = @_SPRITE_VTX_COUNT * @_ixPool.dirtySize()
      if vtxCount > 0
        console.log ">>>", vtxCount
        @_gl.drawArrays(@_gl.TRIANGLES, 0, vtxCount)

  create: (cfg = null) ->
    cfg = applyDef cfg, 
      size: {x:100, y:100}

      
    ix  = @_ixPool.reserve()
    if not ix?
      console.error "TODO: BUFFER TO SMALL"

    sprite = new Sprite
      buffer : @
      id     : ix
      size   : cfg.size
    
    @markDirty sprite
    sprite

  render: () ->
    # TODO: check on real use case if bulk update is faster
    USE_BULK_UPDATE = false

    INT_BYTES = 4
    VTX_DIM   = 3
    VTX_ELEMS = @_SPRITE_VTX_COUNT * VTX_DIM

    dirtyRange = null

    if USE_BULK_UPDATE
      dirtyRange =
        min : undefined
        max : undefined

    buffer = @_buffers.position

    for sprite in @__dirty
      sprite.update()

      srcOffset = sprite.id * VTX_ELEMS   
      p = vec4.create(); p[3] = 1

      p[0] = 0 
      p[1] = 0 
      p[2] = 0
      vec4.transformMat4 p, p, sprite.xform
      buffer.js[srcOffset]     = p[0]
      buffer.js[srcOffset + 1] = p[1]
      buffer.js[srcOffset + 2] = p[2]
      
      p[0] = 0 
      p[1] = sprite.size.y
      p[2] = 0
      vec4.transformMat4 p, p, sprite.xform
      buffer.js[srcOffset + 3] = p[0]
      buffer.js[srcOffset + 4] = p[1]
      buffer.js[srcOffset + 5] = p[2]
      
      p[0] = sprite.size.x
      p[1] = 0
      p[2] = 0
      vec4.transformMat4 p, p, sprite.xform
      buffer.js[srcOffset + 6] = p[0]
      buffer.js[srcOffset + 7] = p[1]
      buffer.js[srcOffset + 8] = p[2]
      
      p[0] = 0
      p[1] = sprite.size.y
      p[2] = 0
      vec4.transformMat4 p, p, sprite.xform
      buffer.js[srcOffset + 9]  = p[0]
      buffer.js[srcOffset + 10] = p[1]
      buffer.js[srcOffset + 11] = p[2]
      
      p[0] = sprite.size.x
      p[1] = sprite.size.y
      p[2] = 0
      vec4.transformMat4 p, p, sprite.xform
      buffer.js[srcOffset + 12] = p[0]
      buffer.js[srcOffset + 13] = p[1]
      buffer.js[srcOffset + 14] = p[2]
      
      p[0] = sprite.size.x
      p[1] = 0
      p[2] = 0
      vec4.transformMat4 p, p, sprite.xform
      buffer.js[srcOffset + 15] = p[0]
      buffer.js[srcOffset + 16] = p[1]
      buffer.js[srcOffset + 17] = p[2]
      
      if USE_BULK_UPDATE
        if not (sprite.id >= dirtyRange.min) then dirtyRange.min = sprite.id
        if not (sprite.id <= dirtyRange.max) then dirtyRange.max = sprite.id
      else
        dstByteOffset = INT_BYTES * srcOffset
        length        = VTX_ELEMS
        arrayBufferSubData @_gl, buffer.gl, dstByteOffset, buffer.js, 
                           srcOffset, length 

    if USE_BULK_UPDATE
      srcOffset     = dirtyRange.min * VTX_ELEMS
      dstByteOffset = INT_BYTES * srcOffset
      length        = VTX_ELEMS * (dirtyRange.max - dirtyRange.min + 1)
      arrayBufferSubData @_gl, buffer.gl, dstByteOffset, buffer.js, 
                         srcOffset, length 

    __dirty = []
      


  
class Foo extends Composable 
  cons: (cfg) -> 
    @mixin displayObjectMixin, [], cfg
    @size    = {x: 100, y: 100}
    @configure cfg

class Bar extends DisplayObject 
  cons: (cfg = {}) -> 
    super []
    @size = cfg.size || {x: 100, y: 100}

txxx = (cfg = {}) ->
  dob  : new DisplayObject []
  size : cfg.size || {x: 100, y: 100}

main = () ->
  # Get A WebGL context
  canvas = document.getElementById("canvas")
  gl = canvas.getContext("webgl2")
  if (!gl) 
    return
  
  t1 = Date.now()
  for i in [0 .. 10000]
    a = new Foo
  t2 = Date.now()
  console.log (t2-t1)
  
  t1 = Date.now()
  for i in [0 .. 10000]
    a = new Bar
  t2 = Date.now()
  console.log (t2-t1)

  t1 = Date.now()
  for i in [0 .. 10000]
    a = txxx()
  t2 = Date.now()
  console.log (t2-t1)
  
  # Use our boilerplate utils to compile the shaders and link into a program
  program = utils.createProgramFromSources(gl,
      [vertexShaderSource, fragmentShaderSource])

  # look up where the vertex data needs to go.
  # locs.attribute.position = gl.getAttribLocation(program.glProgram, "position")
  # locs.attribute.color = gl.getAttribLocation(program.glProgram, "color")

  # look up uniform locations
  # locs.uniform.matrix = gl.getUniformLocation(program.glProgram, "matrix")


  variables =
    attribute:
      position : null
      color    : null
    uniform:
      matrix   : null



  sb1 = new SpriteBuffer gl, program,variables

  s1 = sb1.create()
  s1.position.x = 20

  console.log s1
  # vao = gl.createVertexArray()

  # withVAO gl, vao, ->
  # gl.bindVertexArray(vao)



    

  radToDeg = (r) ->
    return r * 180 / Math.PI
  

  degToRad = (d) ->
    return d * Math.PI / 180
  

  # First let's make some variables
  # to hold the translation,
  fieldOfViewRadians = degToRad(60)
  cameraAngleRadians = degToRad(0);





  # Draw the scene.
  drawScene = () ->
    radius = 200;

    utils.resizeCanvasToDisplaySize(gl.canvas);

    # Tell WebGL how to convert from clip space to pixels
    gl.viewport(0, 0, gl.canvas.width, gl.canvas.height);

    # Clear the canvas
    gl.clearColor(0, 0, 0, 0);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

    # turn on depth testing
    # gl.enable(gl.DEPTH_TEST);

    # tell webgl to cull faces
    # gl.enable(gl.CULL_FACE);

    # Tell it to use our program (pair of shaders)
    gl.useProgram(program.glProgram);

    # Bind the attribute/buffer set we want.
    # gl.bindVertexArray(vao);

    # Compute the matrix
    aspect = gl.canvas.clientWidth / gl.canvas.clientHeight;
    zNear = 1;
    zFar = 2000;
    projectionMatrix = m4.perspective(fieldOfViewRadians, aspect, zNear, zFar);

    # Compute the position of the first F
    fPosition = [radius, 0, 0];

    # Use matrix math to compute a position on the circle.
    cameraMatrix = m4.yRotation(cameraAngleRadians);
    cameraMatrix = m4.translate(cameraMatrix, 0, 50, radius * 1.5);

    # Get the camera's postion from the matrix we computed
    cameraPosition = [
      cameraMatrix[12],
      cameraMatrix[13],
      cameraMatrix[14],
    ];

    up = [0, 1, 0];

    # Compute the camera's matrix using look at.
    cameraMatrix = m4.lookAt(cameraPosition, fPosition, up);

    # Make a view matrix from the camera matrix.
    viewMatrix = m4.inverse(cameraMatrix);

    # create a viewProjection matrix. This will both apply perspective
    # AND move the world so that the camera is effectively the origin
    viewProjectionMatrix = m4.multiply(projectionMatrix, viewMatrix);

    sb1.draw viewProjectionMatrix

  

  drawScene()

  updateCameraAngle = (event, ui) ->
    cameraAngleRadians = degToRad(ui.value);
    drawScene();

  # Setup a ui.
  webglLessonsUI.setupSlider("#cameraAngle", {value: radToDeg(cameraAngleRadians), slide: updateCameraAngle, min: -360, max: 360});

  










`
var m4 = {

  perspective: function(fieldOfViewInRadians, aspect, near, far) {
    var f = Math.tan(Math.PI * 0.5 - 0.5 * fieldOfViewInRadians);
    var rangeInv = 1.0 / (near - far);

    return [
      f / aspect, 0, 0, 0,
      0, f, 0, 0,
      0, 0, (near + far) * rangeInv, -1,
      0, 0, near * far * rangeInv * 2, 0,
    ];
  },

  projection: function(width, height, depth) {
    // Note: This matrix flips the Y axis so 0 is at the top.
    return [
       2 / width, 0, 0, 0,
       0, -2 / height, 0, 0,
       0, 0, 2 / depth, 0,
      -1, 1, 0, 1,
    ];
  },

  multiply: function(a, b) {
    var a00 = a[0 * 4 + 0];
    var a01 = a[0 * 4 + 1];
    var a02 = a[0 * 4 + 2];
    var a03 = a[0 * 4 + 3];
    var a10 = a[1 * 4 + 0];
    var a11 = a[1 * 4 + 1];
    var a12 = a[1 * 4 + 2];
    var a13 = a[1 * 4 + 3];
    var a20 = a[2 * 4 + 0];
    var a21 = a[2 * 4 + 1];
    var a22 = a[2 * 4 + 2];
    var a23 = a[2 * 4 + 3];
    var a30 = a[3 * 4 + 0];
    var a31 = a[3 * 4 + 1];
    var a32 = a[3 * 4 + 2];
    var a33 = a[3 * 4 + 3];
    var b00 = b[0 * 4 + 0];
    var b01 = b[0 * 4 + 1];
    var b02 = b[0 * 4 + 2];
    var b03 = b[0 * 4 + 3];
    var b10 = b[1 * 4 + 0];
    var b11 = b[1 * 4 + 1];
    var b12 = b[1 * 4 + 2];
    var b13 = b[1 * 4 + 3];
    var b20 = b[2 * 4 + 0];
    var b21 = b[2 * 4 + 1];
    var b22 = b[2 * 4 + 2];
    var b23 = b[2 * 4 + 3];
    var b30 = b[3 * 4 + 0];
    var b31 = b[3 * 4 + 1];
    var b32 = b[3 * 4 + 2];
    var b33 = b[3 * 4 + 3];
    return [
      b00 * a00 + b01 * a10 + b02 * a20 + b03 * a30,
      b00 * a01 + b01 * a11 + b02 * a21 + b03 * a31,
      b00 * a02 + b01 * a12 + b02 * a22 + b03 * a32,
      b00 * a03 + b01 * a13 + b02 * a23 + b03 * a33,
      b10 * a00 + b11 * a10 + b12 * a20 + b13 * a30,
      b10 * a01 + b11 * a11 + b12 * a21 + b13 * a31,
      b10 * a02 + b11 * a12 + b12 * a22 + b13 * a32,
      b10 * a03 + b11 * a13 + b12 * a23 + b13 * a33,
      b20 * a00 + b21 * a10 + b22 * a20 + b23 * a30,
      b20 * a01 + b21 * a11 + b22 * a21 + b23 * a31,
      b20 * a02 + b21 * a12 + b22 * a22 + b23 * a32,
      b20 * a03 + b21 * a13 + b22 * a23 + b23 * a33,
      b30 * a00 + b31 * a10 + b32 * a20 + b33 * a30,
      b30 * a01 + b31 * a11 + b32 * a21 + b33 * a31,
      b30 * a02 + b31 * a12 + b32 * a22 + b33 * a32,
      b30 * a03 + b31 * a13 + b32 * a23 + b33 * a33,
    ];
  },

  translation: function(tx, ty, tz) {
    return [
       1,  0,  0,  0,
       0,  1,  0,  0,
       0,  0,  1,  0,
       tx, ty, tz, 1,
    ];
  },

  xRotation: function(angleInRadians) {
    var c = Math.cos(angleInRadians);
    var s = Math.sin(angleInRadians);

    return [
      1, 0, 0, 0,
      0, c, s, 0,
      0, -s, c, 0,
      0, 0, 0, 1,
    ];
  },

  yRotation: function(angleInRadians) {
    var c = Math.cos(angleInRadians);
    var s = Math.sin(angleInRadians);

    return [
      c, 0, -s, 0,
      0, 1, 0, 0,
      s, 0, c, 0,
      0, 0, 0, 1,
    ];
  },

  zRotation: function(angleInRadians) {
    var c = Math.cos(angleInRadians);
    var s = Math.sin(angleInRadians);

    return [
       c, s, 0, 0,
      -s, c, 0, 0,
       0, 0, 1, 0,
       0, 0, 0, 1,
    ];
  },

  scaling: function(sx, sy, sz) {
    return [
      sx, 0,  0,  0,
      0, sy,  0,  0,
      0,  0, sz,  0,
      0,  0,  0,  1,
    ];
  },

  translate: function(m, tx, ty, tz) {
    return m4.multiply(m, m4.translation(tx, ty, tz));
  },

  xRotate: function(m, angleInRadians) {
    return m4.multiply(m, m4.xRotation(angleInRadians));
  },

  yRotate: function(m, angleInRadians) {
    return m4.multiply(m, m4.yRotation(angleInRadians));
  },

  zRotate: function(m, angleInRadians) {
    return m4.multiply(m, m4.zRotation(angleInRadians));
  },

  scale: function(m, sx, sy, sz) {
    return m4.multiply(m, m4.scaling(sx, sy, sz));
  },

  inverse: function(m) {
    var m00 = m[0 * 4 + 0];
    var m01 = m[0 * 4 + 1];
    var m02 = m[0 * 4 + 2];
    var m03 = m[0 * 4 + 3];
    var m10 = m[1 * 4 + 0];
    var m11 = m[1 * 4 + 1];
    var m12 = m[1 * 4 + 2];
    var m13 = m[1 * 4 + 3];
    var m20 = m[2 * 4 + 0];
    var m21 = m[2 * 4 + 1];
    var m22 = m[2 * 4 + 2];
    var m23 = m[2 * 4 + 3];
    var m30 = m[3 * 4 + 0];
    var m31 = m[3 * 4 + 1];
    var m32 = m[3 * 4 + 2];
    var m33 = m[3 * 4 + 3];
    var tmp_0  = m22 * m33;
    var tmp_1  = m32 * m23;
    var tmp_2  = m12 * m33;
    var tmp_3  = m32 * m13;
    var tmp_4  = m12 * m23;
    var tmp_5  = m22 * m13;
    var tmp_6  = m02 * m33;
    var tmp_7  = m32 * m03;
    var tmp_8  = m02 * m23;
    var tmp_9  = m22 * m03;
    var tmp_10 = m02 * m13;
    var tmp_11 = m12 * m03;
    var tmp_12 = m20 * m31;
    var tmp_13 = m30 * m21;
    var tmp_14 = m10 * m31;
    var tmp_15 = m30 * m11;
    var tmp_16 = m10 * m21;
    var tmp_17 = m20 * m11;
    var tmp_18 = m00 * m31;
    var tmp_19 = m30 * m01;
    var tmp_20 = m00 * m21;
    var tmp_21 = m20 * m01;
    var tmp_22 = m00 * m11;
    var tmp_23 = m10 * m01;

    var t0 = (tmp_0 * m11 + tmp_3 * m21 + tmp_4 * m31) -
             (tmp_1 * m11 + tmp_2 * m21 + tmp_5 * m31);
    var t1 = (tmp_1 * m01 + tmp_6 * m21 + tmp_9 * m31) -
             (tmp_0 * m01 + tmp_7 * m21 + tmp_8 * m31);
    var t2 = (tmp_2 * m01 + tmp_7 * m11 + tmp_10 * m31) -
             (tmp_3 * m01 + tmp_6 * m11 + tmp_11 * m31);
    var t3 = (tmp_5 * m01 + tmp_8 * m11 + tmp_11 * m21) -
             (tmp_4 * m01 + tmp_9 * m11 + tmp_10 * m21);

    var d = 1.0 / (m00 * t0 + m10 * t1 + m20 * t2 + m30 * t3);

    return [
      d * t0,
      d * t1,
      d * t2,
      d * t3,
      d * ((tmp_1 * m10 + tmp_2 * m20 + tmp_5 * m30) -
           (tmp_0 * m10 + tmp_3 * m20 + tmp_4 * m30)),
      d * ((tmp_0 * m00 + tmp_7 * m20 + tmp_8 * m30) -
           (tmp_1 * m00 + tmp_6 * m20 + tmp_9 * m30)),
      d * ((tmp_3 * m00 + tmp_6 * m10 + tmp_11 * m30) -
           (tmp_2 * m00 + tmp_7 * m10 + tmp_10 * m30)),
      d * ((tmp_4 * m00 + tmp_9 * m10 + tmp_10 * m20) -
           (tmp_5 * m00 + tmp_8 * m10 + tmp_11 * m20)),
      d * ((tmp_12 * m13 + tmp_15 * m23 + tmp_16 * m33) -
           (tmp_13 * m13 + tmp_14 * m23 + tmp_17 * m33)),
      d * ((tmp_13 * m03 + tmp_18 * m23 + tmp_21 * m33) -
           (tmp_12 * m03 + tmp_19 * m23 + tmp_20 * m33)),
      d * ((tmp_14 * m03 + tmp_19 * m13 + tmp_22 * m33) -
           (tmp_15 * m03 + tmp_18 * m13 + tmp_23 * m33)),
      d * ((tmp_17 * m03 + tmp_20 * m13 + tmp_23 * m23) -
           (tmp_16 * m03 + tmp_21 * m13 + tmp_22 * m23)),
      d * ((tmp_14 * m22 + tmp_17 * m32 + tmp_13 * m12) -
           (tmp_16 * m32 + tmp_12 * m12 + tmp_15 * m22)),
      d * ((tmp_20 * m32 + tmp_12 * m02 + tmp_19 * m22) -
           (tmp_18 * m22 + tmp_21 * m32 + tmp_13 * m02)),
      d * ((tmp_18 * m12 + tmp_23 * m32 + tmp_15 * m02) -
           (tmp_22 * m32 + tmp_14 * m02 + tmp_19 * m12)),
      d * ((tmp_22 * m22 + tmp_16 * m02 + tmp_21 * m12) -
           (tmp_20 * m12 + tmp_23 * m22 + tmp_17 * m02)),
    ];
  },

  cross: function(a, b) {
    return [
       a[1] * b[2] - a[2] * b[1],
       a[2] * b[0] - a[0] * b[2],
       a[0] * b[1] - a[1] * b[0],
    ];
  },

  subtractVectors: function(a, b) {
    return [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
  },

  normalize: function(v) {
    var length = Math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
    // make sure we don't divide by 0.
    if (length > 0.00001) {
      return [v[0] / length, v[1] / length, v[2] / length];
    } else {
      return [0, 0, 0];
    }
  },

  lookAt: function(cameraPosition, target, up) {
    var zAxis = m4.normalize(
        m4.subtractVectors(cameraPosition, target));
    var xAxis = m4.cross(up, zAxis);
    var yAxis = m4.cross(zAxis, xAxis);

    return [
      xAxis[0], xAxis[1], xAxis[2], 0,
      yAxis[0], yAxis[1], yAxis[2], 0,
      zAxis[0], zAxis[1], zAxis[2], 0,
      cameraPosition[0],
      cameraPosition[1],
      cameraPosition[2],
      1,
    ];
  },

  transformVector: function(m, v) {
    var dst = [];
    for (var i = 0; i < 4; ++i) {
      dst[i] = 0.0;
      for (var j = 0; j < 4; ++j) {
        dst[i] += v[j] * m[j * 4 + i];
      }
    }
    return dst;
  },

};
`

main()