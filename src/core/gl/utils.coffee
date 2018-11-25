###################
### WebGL Utils ###
###################

export withVAO = (gl, vao, f) -> 
  gl.bindVertexArray vao
  out = f()
  gl.bindVertexArray null
  out

export withBuffer = (gl, type, buffer, f) -> 
  gl.bindBuffer type, buffer
  out = f()
  gl.bindBuffer type, null
  out

export withArrayBuffer = (gl, buffer, f) ->
  withBuffer gl, gl.ARRAY_BUFFER, buffer, f 
  
export arrayBufferSubData = (gl, buffer, dstByteOffset, srcData, srcOffset, length) ->
  withArrayBuffer gl, buffer, =>
    gl.bufferSubData gl.ARRAY_BUFFER, dstByteOffset, srcData, srcOffset, length

export withNewArrayBuffer = (gl, f) ->
  buffer = gl.createBuffer()
  withArrayBuffer gl, buffer, => f buffer