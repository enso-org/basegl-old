uv   = v_uv;
mat4 xform         = mat4(v_xform1, v_xform2, v_xform3, v_xform4);
vec3 spacePosition = vec3(v_uv.x * v_bbox.x, v_uv.y * v_bbox.y, 0.0);
local              = spacePosition;
spacePosition      = (xform * vec4(spacePosition, 1.0)).xyz;
vec3 p1            = spacePosition;
vec4 eyeT          = modelViewMatrix * vec4(p1, 1.0);
gl_Position        = projectionMatrix * eyeT;
eye                = eyeT.xyz;
eye.z              = -eye.z;
scaledEye          = eye;
scaledEye.z        = scaledEye.z / 1000.0;

symbolID           = v_symbolID;
symbolFamilyID     = v_symbolFamilyID;
pointerEvents      = v_pointerEvents;
zIndex             = v_zIndex;

zoomLevel = zoom;

// gl_Position.z += v_zIndex - 100.0;
world = gl_Position.xyz;
bbox = v_bbox;
