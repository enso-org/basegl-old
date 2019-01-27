
// FIXME - THESE NEED TO BE PROVIDED
int drawBuffer = 0;
int displayMode = 0;
float pointerEvents = 1.0;
int pointerEvents2 = 1;

void main() {
  vec2      p     = local.xy ;
  shape     sss   = _main(sdf_sampler2(p));
  int       sid   = sss.id;
  float     alpha = sdf_render(sss.sdf.distance);

  float idMask           = (float(sid)) > 0. ? 1. : 0.; // sss.cd.a * float(sid)
  float symbolFamilyID_r = float(floor(symbolFamilyID + 0.5));
  float symbolID_r       = float(floor(symbolID + 0.5));

  displayMode = 1;

  if (drawBuffer == 0) {
      if (displayMode == 0) {
          output_color = sss.color;
          output_color *= sss.density;
      } else if (displayMode == 1) {
          vec3 col = distanceMeter(sss.sdf.distance, 500.0 * zoom, vec3(0.0,1.0,0.0), 500.0/zoom);
          col = Uncharted2ToneMapping(col);
          output_color = vec4(col, 1.0);
      } else if (displayMode == 2) {
          if (pointerEvents > 0.0) {
              vec3 cd = hsv2rgb(vec3(symbolFamilyID_r/4.0, 1.0, 1.0));
              output_color = vec4(cd, idMask);
          } else {
              output_color = vec4(0.0);
          }
      } else if (displayMode == 3) {
          vec3 cd = hsv2rgb(vec3(symbolID_r/4.0, 1.0, idMask));
          output_color = vec4(cd, idMask);
      } else if (displayMode == 4) {
          vec3 cd = hsv2rgb(vec3(float(sid)/20.0, 1.0, idMask));
          output_color = vec4(cd, idMask);
      } else if (displayMode == 5) {
          output_color = vec4(zIndex/100.0);
          output_color.a = idMask;
      }
  } else if (drawBuffer == 1) {
      if (pointerEvents > 0.0) {
          output_color = vec4(symbolFamilyID_r,symbolID_r,float(sid),idMask);
      } else {
          output_color = vec4(0.0);
      }
  }
//   output_id = vec4(symbolFamilyID_r,symbolID_r,float(sid),idMask);
//   output_id *= pointerEvents;
  output_id = vec4(1.5,2.0,3.0,4.0);
  
//   int x = 8388607;
//   float xx = intBitsToFloat(x);
//   int xxx = floatBitsToInt(xx);
  
//   if (x == xxx) {
//       output_id = vec4(1.0,0.0,0.0,1.0);
//   } else {
//       output_id = vec4(0.0,1.0,0.0,1.0);      
//   }
  // gl_FragColor = vec4(luv.x, luv.y, 0.0, 1.0);
}
// 3124124124 -> -1170843172
// 3124124125 -> -1170843171
// 53280955

// 8388608

