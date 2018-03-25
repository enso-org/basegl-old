import * as basegl   from 'basegl'
import * as Color    from 'basegl/display/Color'
import * as OpenType from 'opentype.js'
import * as Promise  from 'bluebird'
import * as Property from 'basegl/object/Property'
import * as Shape    from 'basegl/display/Shape'
import * as Image    from 'basegl/display/Image'

import {Symbol, group}                     from 'basegl/display/Symbol'
import {BinPack}                           from 'basegl/display/texture/BinPack'
import {Composition, Composable}           from 'basegl/object/Property'
import {typedValue}                        from 'basegl/display/Symbol'
import {DisplayObject, displayObjectMixin} from 'basegl/display/DisplayObject'


letterShape = new Shape.RawShader
  fragment: '''

const int SAMPLENUM = 1;

float foo (float a, float d) {
  float smoothing = 1.0/fontSize;
  return 1. - smoothstep(0.5 - smoothing, 0.5 + smoothing, (a - d));
}

float multisample_gaussian3x3 (mat3 arr, float d) {
    return foo(arr[0][0], d) * 0.011
         + foo(arr[0][1], d) * 0.084
         + foo(arr[0][2], d) * 0.011
         + foo(arr[1][0], d) * 0.084
         + foo(arr[1][1], d) * 0.62
         + foo(arr[1][2], d) * 0.084
         + foo(arr[2][0], d) * 0.011
         + foo(arr[2][1], d) * 0.084
         + foo(arr[2][2], d) * 0.011;
}


void main() {
  float smoothing = zoom * 1.0/fontSize;

  float dx = 1./2048.;
  float dy = 1./2048.;

  vec2 uv2 = uv;

  uv2.x /= (glyphsTextureSize / glyphLoc[2]); // width
  uv2.y /= (glyphsTextureSize / glyphLoc[3]); // width
  uv2.x += glyphLoc.x / glyphsTextureSize;
  uv2.y += glyphLoc.y / glyphsTextureSize;

  //uv2.x += 0.1;
  vec4 img = texture2D(glyphsTexture, uv2);
  //float s = img.r;
  vec4 red   = rgb2lch(vec4(1.0,0.0,0.0,1.0));
  vec4 white = rgb2lch(vec4(1.0));
  vec4 cd = white;

  float realZoom = glyphZoom * zoom; // texture is scaled for tests!


  mat3 samples;

  samples[0][0] = texture2D(glyphsTexture, vec2(uv2.x + dx * (-1.*realZoom/2.), uv2.y + dy * (-1.*realZoom/2.))).r;
  samples[0][1] = texture2D(glyphsTexture, vec2(uv2.x + dx * ( 0.*realZoom/2.), uv2.y + dy * (-1.*realZoom/2.))).r;
  samples[0][2] = texture2D(glyphsTexture, vec2(uv2.x + dx * ( 1.*realZoom/2.), uv2.y + dy * (-1.*realZoom/2.))).r;
  samples[1][0] = texture2D(glyphsTexture, vec2(uv2.x + dx * (-1.*realZoom/2.), uv2.y + dy * ( 0.*realZoom/2.))).r;
  samples[1][1] = texture2D(glyphsTexture, vec2(uv2.x + dx * ( 0.*realZoom/2.), uv2.y + dy * ( 0.*realZoom/2.))).r;
  samples[1][2] = texture2D(glyphsTexture, vec2(uv2.x + dx * ( 1.*realZoom/2.), uv2.y + dy * ( 0.*realZoom/2.))).r;
  samples[2][0] = texture2D(glyphsTexture, vec2(uv2.x + dx * (-1.*realZoom/2.), uv2.y + dy * ( 1.*realZoom/2.))).r;
  samples[2][1] = texture2D(glyphsTexture, vec2(uv2.x + dx * ( 0.*realZoom/2.), uv2.y + dy * ( 1.*realZoom/2.))).r;
  samples[2][2] = texture2D(glyphsTexture, vec2(uv2.x + dx * ( 1.*realZoom/2.), uv2.y + dy * ( 1.*realZoom/2.))).r;

  float s = pow(multisample_gaussian3x3(samples, realZoom/150.0),realZoom/2.);

  float alpha = color.a * (1. - smoothstep(0.5 - smoothing, 0.5 + smoothing, img.r));
  //float alpha = s;
  gl_FragColor = vec4(color.rgb, alpha);
  //gl_FragColor = vec4((img.rgb - 0.5)*2.0, 1.0);
}

'''


zip = (arrs...) =>
  out = []
  maxLen = Math.min (a.length for a in arrs)...
  for idx in [0...maxLen]
    el = []
    for arr in arrs
      el.push arr[idx]
    out.push el
  out



class IDMap
  constructor: () ->
    @_lastID = 0
    @_map    = new Map

  _nextID: () ->
    id = @_lastID
    @_lastID += 1
    id

  get: (id) ->
    @_map.get id

  insert: (a) ->
    id = @_nextID()
    @_map.set id, a
    id


#####################
### Texture utils ###
#####################

export textureSizeFor  = (i) -> closestPowerOf2 (Math.ceil (Math.sqrt i))
export closestPowerOf2 = (i) -> Math.pow(2, Math.ceil(Math.log2 i))

export encodeArrayInTexture = (arr) ->
  len     = arr.length
  els     = Math.ceil (len/4)
  size    = textureSizeFor els
  tarr    = new Float32Array (size*size*4)
  texture = new Image.DataTexture tarr, size, size, THREE.RGBAFormat, THREE.FloatType
  texture.needsUpdate = true
  for idx in [0...len]
    tarr[idx] = arr[idx]
  {texture, size}



##################
### Glyph path ###
##################

PATH_COMMAND =
  Z: 0 # end of letter
  M: 1
  L: 2
  Q: 3

encodePath    = (path) -> encodePathMut path, []
encodePathMut = (path, cmds) ->
  bbox = path.getBoundingBox()
  offx = bbox.x1
  offy = bbox.y1
  offy2 = bbox.y2
  for segment in path.commands
    switch segment.type
      when 'M' then cmds.push PATH_COMMAND.M, (segment.x - offx) , (segment.y - offy)
      when 'L' then cmds.push PATH_COMMAND.L, (segment.x - offx) , (segment.y - offy)
      when 'Q' then cmds.push PATH_COMMAND.Q, (segment.x1 - offx), (segment.y1 - offy), (segment.x - offx), (segment.y - offy)
      # when 'Z' then cmds.push PATH_COMMAND.Z
  cmds

generatePathsTexture = (paths) ->
  offsets  = [0]
  commands = []
  offset = 0
  for path in paths
    for cmd in encodePath path
      commands.push cmd
      offset += 1
    offsets.push offset
  obj = encodeArrayInTexture commands
  obj.offsets = offsets
  obj





pathFlipYMut = (path) ->
  ncmds = []
  for cmd in path.commands
    ncmd = {type: cmd.type, x: cmd.x, y: -cmd.y}
    if cmd.x1?
      ncmd.x1 = cmd.x1
      ncmd.y1 = -cmd.y1
    ncmds.push ncmd
  path.commands = ncmds
  path



#############
### Atlas ###
#############

loadFont = Promise.promisify OpenType.load

export class GlyphLocation
  constructor: (@x, @y, @width, @height, @spread) ->

export class GlyphShape
  constructor: (@x, @y, @advanceWidth) ->

export class GlyphInfo
  constructor: (@shape, @loc) ->

class Atlas extends Composable
  cons: (fontFamily, cfg) ->
    @_fontFamily = fontFamily
    @_size       = 2048
    @_glyphSize  = 64
    @_spread     = 16
    @_preload    = [32..126]
    @configure cfg

    @_glyphs = new Map
    @_pack   = new BinPack @_size, @_size
    @_font   = null
    @_rt     = new THREE.WebGLRenderTarget @_size, @_size
    @_scene  = basegl.scene
      autoUpdate : false
      width      : @_size
      height     : @_size

    @_texture = new THREE.CanvasTexture @_scene.symbolModel.domElement

    @ready = loadFont(@_fontFamily).then (font) =>
      @_font = font
      @loadGlyphs @_preload
      @

    @_letterDef = new Symbol letterShape
    @_letterDef.bbox.xy = [@_glyphSize,@_glyphSize]
    @_letterDef.variables.glyphLoc  = typedValue 'vec4' # FIXME utilize Vector defaults
    @_letterDef.variables.glyphZoom = 1
    @_letterDef.variables.fontSize  = @_glyphSize
    @_letterDef.variables.color     = new Color.RGB [1,1,1]
    @_letterDef.globalVariables.glyphsTexture = @_texture
    @_letterDef.globalVariables.glyphsTextureSize = @_size

    @_glyphSymbol = new Symbol glyphShape



  getInfo: (glyph) ->
    @_glyphs.get glyph

  loadGlyphs: (args...) ->
    # console.log (64*font.descender/font.unitsPerEm)
    chars = []
    addInput = (a) =>
      if a instanceof Array
        for i in a
          addInput i
      else if typeof a == 'string'
        for char from a
          chars.push a
      else if typeof a == 'number'
        chars.push (String.fromCharCode a)
    addInput args

    glyphPaths = []
    glyphDefs  = []
    locs       = []
    canvas     = {w:0, h:0}
    for char in chars
      glyph     = @_font.charToGlyph char
      path      = pathFlipYMut (@_font.getPath char, 0, 0, @glyphSize)
      pathBBox  = path.getBoundingBox()
      widthRaw  = pathBBox.x2 - pathBBox.x1
      heightRaw = pathBBox.y2 - pathBBox.y1
      width     = widthRaw  + 2*@spread
      height    = heightRaw + 2*@spread
      rect      = @_pack.insert width,height
      if not rect
        throw "Cannot pack letter to atlas, out of space." # TODO: resize atlas
        return false
      canvas.w += width
      canvas.h += Math.max canvas.h, height
      loc       = new GlyphLocation (rect.x + @spread), (rect.y + @spread), widthRaw, heightRaw, @spread
      shape     = new GlyphShape pathBBox.x1, pathBBox.y1, (@glyphSize*glyph.advanceWidth/@_font.unitsPerEm)
      console.log "%%%", char, glyph.advanceWidth
      info      = new GlyphInfo shape, loc
      locs.push loc
      @_glyphs.set char, info
      glyphPaths.push path

    shapeDef = generatePathsTexture glyphPaths

    @_glyphSymbol.globalVariables.commands = shapeDef.texture
    @_glyphSymbol.globalVariables.size     = shapeDef.size
    @_glyphSymbol.globalVariables.spread   = @spread
    @_glyphSymbol.variables.offset     = 0
    @_glyphSymbol.variables.nextOffset = 0

    offX = 0
    for [loc, offset, nextOffset] in zip(locs, shapeDef.offsets, shapeDef.offsets.slice(1))
      lx = loc.x - loc.spread
      ly = loc.y - loc.spread
      lw = loc.width  + 2*loc.spread
      lh = loc.height + 2*loc.spread
      glyphInstance = @scene.add @_glyphSymbol
      glyphInstance.position.xy = [lx,ly]
      glyphInstance.bbox.xy     = [lw, lh]
      glyphInstance.variables.offset     = offset
      glyphInstance.variables.nextOffset = nextOffset
      offX += lw

    # FIXME: why we need to call update twice?
    @scene.update()
    @scene.update()
    @texture.needsUpdate = true



export atlas = Property.consAlias Atlas


class Manager extends Composable
  cons: () ->
    @_fontSrcMap = new Map
    @_atlasses   = new Map

  register: (name, path) ->
    # TODO: We can make it automatically populated with registerSource
    #       and using XHR to list that directory
    @_fontSrcMap.set name, path

  load: (name, cfg) ->
    fontFamily = @lookupFontSource name
    a = atlas fontFamily, cfg
    @atlasses.set name, a
    a.ready

  lookupFontSource: (name) -> @fontSrcMap.get name
  lookupAtlas:      (name) -> @atlasses.get name


export manager = Property.consAlias Manager



############
### Text ###
############

class Char extends Composable
  cons: (@raw, cfg) ->
    @_text         = null
    @_symbol       = null
    @_size         = 64
    @__color       = Color.rgb [1,1,1]
    @__idx         = 0
    @_advanceWidth = 0
    @configure cfg
  @getter 'color', () -> @__color
  @setter 'color', (color) -> 
    @symbol.variables.color = color
    @__color = color
  @getter 'bbox', () -> @symbol.bbox
    

class Text extends Composable
  cons: (cfg) ->
    @mixin displayObjectMixin, [], cfg
    @_scene        = null
    @_fontFamily   = null 
    @_fontManager  = basegl.fontManager    
    @_size         = 64
    @_color        = Color.rgb [1,1,1]
    @configure cfg
    @_length      = 0
    @_width       = 0
    @_endPosition = {x:0, y:0}
    @_atlas       = @_fontManager.lookupAtlas @_fontFamily
    @_chars       = []
  
  init: (cfg) ->
    if cfg.str?
      @pushStr cfg.str
  
  pushChar: (char) ->
    glyphMaxOff = 2
    scale = char.size / @atlas.glyphSize
    letterSpacing = 10 # FIXME: make related to size
  
    if char.raw == '\n'
      @_endPosition.x = 0
      @_endPosition.y -= char.size
    else
      letter = @scene.add @atlas.letterDef
      info   = @atlas.getInfo char.raw
      loc    = info.loc
      letter.position.xy = [@_endPosition.x, info.shape.y * scale + @_endPosition.y]
      letter.variables.fontSize = char.size        
      letter.variables.color    = char.color        

      gw = loc.width  + 2*glyphMaxOff
      gh = loc.height + 2*glyphMaxOff
      letter.bbox.xy = [gw*scale, gh*scale]
      letter.variables.glyphLoc = [loc.x - glyphMaxOff, loc.y - glyphMaxOff, gw, gh]
      letterWidth    = (info.shape.advanceWidth + letterSpacing) * scale
      @_endPosition.x += letterWidth
      if @_endPosition.x > @_width then @_width = @_endPosition.x
      @addChild letter
      idx                = @_length
      char._symbol       = letter
      char.__idx         = idx
      char._advanceWidth = letterWidth
      @[idx]             = char
      @_chars.push char
      @_length += 1
  
  setColor: (color, start, end) ->
    if start == undefined then start = 0
    if end   == undefined then end   = @length
    for i in [start...end]
      @[i].color = color
    
  pushStr: (str) ->
    for char in str
      char = new Char char, 
        text:  @
        size:  @size
        color: @color
      @pushChar char 
      


export text = Property.consAlias Text



############
### Text ###
############




# class Text extends Composable
#   cons: (cfg) ->
#     @_str         = ''
#     @_fontFamily  = null
#     @_size        = 64
#     @_fontManager = basegl.fontManager
#     @configure cfg
#     @_atlas = @_fontManager.lookupAtlas @_fontFamily
#     if typeof @_str == 'string'
#       @_chars = []
#       for char in @_str
#         @_chars.push (new Char char, cfg)

#   setColor: (color, start, end) ->
#     for char in @chars.slice(start,end)
#       char.color = color

#   addToScene: (scene) ->
#     glyphMaxOff = 2

#     newlines = 0
#     for char in @chars
#       if char.raw == '\n' then newlines += 1

#     scale = @size / @atlas.glyphSize
#     offx  = 0
#     offy  = newlines * @atlas.glyphSize * scale
#     letterSpacing = 0 # FIXME: make related to size
#     letters = []
#     for char in @chars
#       if char.raw == '\n'
#         offx = 0
#         offy -= @size
#       else
#         letter = scene.add @atlas.letterDef
#         info   = @atlas.getInfo char.raw
#         loc    = info.loc
#         letter.position.xy = [offx, info.shape.y * scale + offy]
#         letter.variables.fontSize = @_glyphSize        
#         letter.variables.color    = char.color        

#         gw = loc.width  + 2*glyphMaxOff
#         gh = loc.height + 2*glyphMaxOff
#         letter.bbox.xy = [gw*scale, gh*scale]
#         letter.variables.glyphLoc = [loc.x - glyphMaxOff, loc.y - glyphMaxOff, gw, gh]
#         offx += (loc.width + info.shape.advanceWidth + letterSpacing) * scale
#         letters.push letter

#     textInstance letters, {scene: scene, fontManager: @fontManager, fontFamily: @fontFamily}

# export text = Property.consAlias Text



glyphShape = new Shape.RawShader
  fragment: '''

vec4 texture2DRect (sampler2D sampler, float size, vec2 pixel) {
  float x = (0.5 + pixel.x)/size;
  float y = (0.5 + pixel.y)/size;
  return texture2D(sampler,vec2(x,y));
}

float texture2DAs1D (sampler2D sampler, float size, float idx) {
  float el   = floor(idx/4.0);
  float comp = idx - el*4.0;
  float y    = floor(el/size);
  float x    = el - y*size;
  vec4  val  = texture2DRect(sampler, size, vec2(x,y));
  if      (comp == 0.0) { return val.r; }
  else if (comp == 1.0) { return val.g; }
  else if (comp == 2.0) { return val.b; }
  else if (comp == 3.0) { return val.a; }
  else                  { return -1.0;  }
}

void main() {
  vec2 p = local.xy;
  float s = 9999.0;
  vec4 red   = rgb2lch(vec4(1.0,0.0,0.0,1.0));
  vec4 white = rgb2lch(vec4(1.0));
  vec4 cd = white;


  p -= vec2(spread, spread);
  //p -= vec2(1.0);

  vec2 origin = vec2(0.0);

  float idx = floor(offset+0.5);
  bool isInside = false;
  for (float i=0.0; i<1000.0; i++) {
    if (idx>=nextOffset) { break; }
    float cmd = texture2DAs1D(commands, size, idx);
    if        (cmd == 0.0) { break;
    } else if (cmd == 1.0) { // Move
      idx++; float dx = texture2DAs1D(commands, size, idx);
      idx++; float dy = texture2DAs1D(commands, size, idx);
      p -= vec2(dx,dy) - origin;
      origin = vec2(dx,dy);
    } else if (cmd == 2.0) { // Line
      idx++; float tx = texture2DAs1D(commands, size, idx);
      idx++; float ty = texture2DAs1D(commands, size, idx);
      vec2 tp = vec2(tx,ty);
      tp -= origin;
      origin += tp;
      float ns       = sdf_quadraticCurve           (p, tp, tp);
      bool  interior = quadraticCurve_interiorCheck (p, tp, tp);
      isInside = interiorChec_union(isInside, interior);
      s = sdf_union(s,ns);
      p -= tp;
    } else if (cmd == 3.0) { // Quadratic Curve
      idx++; float cx = texture2DAs1D(commands, size, idx);
      idx++; float cy = texture2DAs1D(commands, size, idx);
      idx++; float tx = texture2DAs1D(commands, size, idx);
      idx++; float ty = texture2DAs1D(commands, size, idx);
      vec2 cp = vec2(cx,cy);
      vec2 tp = vec2(tx,ty);
      cp -= origin;
      tp -= origin;
      origin += tp;
      float ns       = sdf_quadraticCurve           (p, cp, tp);
      bool  interior = quadraticCurve_interiorCheck (p, cp, tp);
      isInside = interiorChec_union(isInside, interior);
      s = sdf_union(s,ns);
      p -= tp;
    }
    idx++;
  }
  if (isInside) { s = -s; }

  float d = s/(2.*spread) + .5;
  //d = s/spread;

  gl_FragColor = vec4(vec3(d),1.0);
  //return sdf_shape(d, 0, vec4(0.0), cd);
}

'''
