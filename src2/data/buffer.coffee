import * as Config from 'basegl/object/config'
import {assert} from 'basegl/lib/runtime-check/assert'

##############
### Buffer ###
##############

# Buffer is a wrapper over any array-like object and exposes element read /
# write functions that can be overriden instead of inflexible index-based
# interface.


patternArray = (t, pat, tgtLen) -> 
  pat  = new t pat
  arr  = new t tgtLen
  len  = pat.length
  buff = arr.buffer
  view = new t pat.buffer, 0, Math.min(len, tgtLen)
  arr.set view
  while true
    if len >= tgtLen then break
    view = new t buff, 0, Math.min(len, tgtLen-len)
    arr.set view, len
    len <<= 1
  arr


export class Buffer

  ### Properties ###
  constructor: (@type, arg, cfg={}) ->
    @_default = cfg.default
    @_array   = @_newArray arg

  _newArray: (arg) ->
    if @_default && arg.constructor == Number
      patternArray @type, @_default, arg
    else new @type arg

  @getter 'array'    , -> @_array
  @getter 'buffer'   , -> @_array.buffer
  @getter 'length'   , -> @_array.length
  @getter 'rawArray' , -> @_array

  ### Read / Write ###
  read: (ix) -> 
    @_array[ix]
  
  write: (ix, v) -> 
    assert (@_array.length > ix), =>
      throw "Index #{ix} is too big, array has #{@_array.length} elements"
    @_array[ix] = v
    null
  
  readMultiple: (ixs) -> 
    @_array[ix] for ix from ixs
  
  writeMultiple: (ixs, vs) -> 
    @write(ix,vs[i]) for ix,i in ixs
    null

  ### Size Management ###
  resize: (newLength) ->
    newArray  = @_newArray newLength
    arrayView = if @length <= newLength then @_array else
      new @type @_array.buffer, 0, newLength
    newArray.set arrayView
    @_array = newArray

  ### Redirect ###
  set: (args...) -> @_array.set args...



############
### View ###
############

# View is a wrapper over any buffer-like object allowing to view the array with
# a defined elements shift.

export class View

  ### Properties ###
  constructor: (@_array, @_offset=0, @_length=0) ->
  @getter 'array'  , -> @_array
  @getter 'buffer' , -> @_array.buffer
  @getter 'length' , -> @_length
  @getter 'offset' , -> @_offset

  ### Read / Write ###
  read:          (x)    -> @_array.read          (x + @_offset)
  write:         (x, v) -> @_array.write         (x + @_offset), v
  readMultiple:  (x)    -> @_array.readMultiple  (x + @_offset for x from x)
  writeMultiple: (x, v) -> @_array.writeMultiple (x + @_offset for x from x), v

  


##################
### Observable ###
##################

# Observable is a wrapper over any buffer-like object allowing to subscribe to
# changes by monkey-patching its methods.

export class Observable

  ### Properties ###

  constructor: (@_array) -> 
  @getter 'array'    , -> @_array
  @getter 'buffer'   , -> @array.buffer
  @getter 'length'   , -> @array.length
  @getter 'rawArray' , -> @array.rawArray


  ### Read / Write ###

  read:         (ix)  -> @array.read         ix
  readMultiple: (ixs) -> @array.readMultiple ixs 
  
  write: (ix, v) -> 
    @array.write ix, v
    @onChanged ix
  
  writeMultiple: (ixs, vs) ->
    @array.writeMultiple ixs, vs 
    @onChangedMultiple ixs

  set: (array, offset=0) ->
    @array.set array, offset
    @onChangedRange offset, array.length


  ### Size Management ###

  resize: (newLength) ->
    oldLength = @_length
    if oldLength != newLength
      @array.resize newLength
      @onResized oldLength, newLength


  ### Events ###  

  onResized: (oldSize, newSize) ->
  onChanged: (ix) ->

  onChangedMultiple: (ixs) ->
    for ix in ixs
      @onChanged ix
  
  onChangedRange: (offset, length) ->
    for ix in [offset ... offset + length]
      @onChanged ix


