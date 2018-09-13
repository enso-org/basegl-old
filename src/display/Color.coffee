import * as Reflect   from 'basegl/object/Reflect'
import * as Property  from 'basegl/object/Property'
import * as GLSL      from 'basegl/display/target/WebGL'
import * as TypeClass from 'basegl/lib/TypeClass'
import * as Math      from 'basegl/math/Common'




mixArrays = (a1, a2, s=0.5) ->
  out = []
  for i in [0..a1.length-1]
    out[i] = Math.add(Math.mul(a1[i],(Math.sub(1,s))),Math.mul(a2[i],s))
  out



#############
### Color ###
#############

export class Color
  constructor: (@_arr) ->

  copy: () ->
    new @constructor @_arr.slice()

Reflect.addTypeInformation Color

addAlpha = (arr) =>
  if arr.length == 3
    arr2 = arr.slice()
    arr2.push(1)
  else
    arr2 = arr
  arr2



###########
### RGB ###
###########

export class RGB extends Color
  Property.swizzleFieldsRGBA @, '_arr'

  constructor: (arr=[0,0,0]) -> super (addAlpha arr)
  @fromInt: (i) ->
    r = (i & 0xff0000) >> 16
    g = (i & 0x00ff00) >> 8
    b = (i & 0x0000ff)
    new RGB [r,g,b]

  toInt: () -> (@r << 16) | (@g << 8) | @b
  toRGB: () -> @

  mix: (c, t=0.5) -> rgb (mixArrays @_arr, c.toRGB()._arr, t)


  TypeClass.implement @, GLSL.toExpr, () ->
    if @a == undefined then GLSL.callExpr 'vec3' , @rgb
    else                    GLSL.callExpr 'vec4' , @rgba

export rgb = Property.consAlias RGB



###########
### HSL ###
###########

export class HSL extends Color
  Property.swizzleFields @, '_arr', ['h','s','l','a']
  constructor: (arr=[0,0,0]) -> super (addAlpha arr)

  mix: (c, t=0.5) -> hsl (mixArrays @_arr, c.toHSL()._arr, t)

  TypeClass.implement @, GLSL.toExpr, () ->
    if @a == undefined then GLSL.callExpr 'vec3' , @hsl
    else                    GLSL.callExpr 'vec4' , @hsla

export hsl = Property.consAlias HSL

Color::toHSL = () -> @.toRGB().toHSL()
HSL::toHSL = () -> @
RGB::toHSL = () ->
  min = Math.min(@r, @g, @b)
  max = Math.max(@r, @g, @b)
  l = (max + min) / 2
  if max == min
    s = 0
    h = Number.NaN
  else
    s = if l < 0.5 then (max - min) / (max + min) else (max - min) / (2 - max - min)

  if r == max then h = (g - b) / (max - min)
  else if (g == max) then h = 2 + (b - r) / (max - min)
  else if (b == max) then h = 4 + (r - g) / (max - min)

  h *= 60;
  h += 360 if h < 0
  arr = [h,s,l]
  if @a != undefined then arr.push @a
  hsl arr


HSL::toRGB = () ->
  if @s == 0
    r = g = b = l
  else
    t3 = [0,0,0]
    c  = [0,0,0]
    t2 = if @l < 0.5 then @l * (1+@s) else @l+@s-@l*@s
    t1 = 2 * @l - t2
    h  = @h/360
    t3[0] = h + 1/3
    t3[1] = h
    t3[2] = h - 1/3
    for i in [0..2]
      t3[i] += 1 if t3[i] < 0
      t3[i] -= 1 if t3[i] > 1
      if 6 * t3[i] < 1
        c[i] = t1 + (t2 - t1) * 6 * t3[i]
      else if 2 * t3[i] < 1
        c[i] = t2
      else if 3 * t3[i] < 2
        c[i] = t1 + (t2 - t1) * ((2 / 3) - t3[i]) * 6
      else
        c[i] = t1
    [r,g,b] = [c[0],c[1],c[2]]
  arr = [r,g,b]
  if @a != undefined then arr.push @a
  rgb arr
