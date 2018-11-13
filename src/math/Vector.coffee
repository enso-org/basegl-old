import * as Reflect  from 'basegl/object/Reflect'
import * as M        from 'basegl/math/Common'
import * as Property from 'basegl/object/Property'



### Definition ###

export class Vector
  Reflect.addTypeInformation @

  ### Constructors ###

  constructor: (@_arr=[0,0,0], @onChanged=()->) ->
  @fromXYZ = (a) -> new Vector [a.x, a.y, a.z]


  ### Properties ###

  Property.swizzleFieldsXYZW @, '_arr'
  Property.swizzleFieldsRGBA @, '_arr'
  Property.swizzleFieldsSTPQ @, '_arr'
  Property.addIndexFieldsStd @, '_arr'

  @getter 'components', -> @_arr


  ### Utils ###

  clone: () -> new Vector @_arr.slice()


  ### Mutable API ###

  componentWiseMut: (a,f) ->
    if typeof a == 'number'
      for v,i in @_arr
        @_arr[i] = f(v,a)
    else
      for v,i in @_arr
        @_arr[i] = f(v,a[i])

  addMut:    (a) -> (@componentWiseMut.call @, a, (v,t) -> v + t); @onChanged(); @
  subMut:    (a) -> (@componentWiseMut.call @, a, (v,t) -> v - t); @onChanged(); @
  mulMut:    (a) -> (@componentWiseMut.call @, a, (v,t) -> v * t); @onChanged(); @
  divMut:    (a) -> (@componentWiseMut.call @, a, (v,t) -> v / t); @onChanged(); @
  zeroMut:       -> @x = 0; @y = 0; @z = 0; @onChanged(); @
  negateMut:     -> @x = -@x; @y = -@y; @z = -@z; @onChanged(); @

  normalizeMut: () ->
    len = @length()
    if len != 0 then @divMut len else @zeroMut()


  ### Immutable API ###

  add:       (a) -> @clone().addMut a
  sub:       (a) -> @clone().subMut a
  mul:       (a) -> @clone().mulMut a
  div:       (a) -> @clone().divMut a
  normalize:     -> @clone().normalizeMut()
  negate:        -> @clone().negateMut()
  length:        -> M.sqrt (@x*@x + @y*@y + @z*@z)


export vector = (x=0, y=0, z=0) -> new Vector [x,y,z]
export point  = (args...) -> vector args...
