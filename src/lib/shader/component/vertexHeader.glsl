precision highp float;
precision highp int;
uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;
attribute vec2 v_uv;
attribute vec3 position;

varying vec2 uv;
varying vec3 world;
varying vec3 local;
varying vec3 eye;
varying vec3 scaledEye;
varying float zoomLevel;
