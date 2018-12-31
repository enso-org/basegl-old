import * as Config          from 'basegl/object/config'
import * as EventDispatcher from 'basegl/event/dispatcher'
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
  @generateAccessors()

  ### Properties ###
  constructor: (@_buffer, @_offset=0, @_length=0) ->

  ### Read / Write ###
  read:          (x)    -> @buffer.read          (x + @offset)
  write:         (x, v) -> @buffer.write         (x + @offset), v
  readMultiple:  (x)    -> @buffer.readMultiple  (x + @offset for x from x)
  writeMultiple: (x, v) -> @buffer.writeMultiple (x + @offset for x from x), v

  


################
### Bindable ###
################

# Bindable is a wrapper over any buffer-like object allowing to subscribe to
# changes by monkey-patching its methods.

export class Bindable
  @generateAccessors()

  ### Properties ###
  
  constructor: (@_buffer) -> 
  @getter 'length'   , -> @buffer.length
  @getter 'rawArray' , -> @buffer.rawArray

  ### Read / Write ###

  read:         (ix)  -> @buffer.read         ix
  readMultiple: (ixs) -> @buffer.readMultiple ixs 
  
  write: (ix, v) -> 
    @buffer.write ix, v
    @onChanged ix
  
  writeMultiple: (ixs, vs) ->
    @buffer.writeMultiple ixs, vs 
    @onChangedMultiple ixs

  set: (buffer, offset=0) ->
    @buffer.set buffer, offset
    @onChangedRange offset, buffer.length


  ### Size Management ###

  resize: (newLength) ->
    oldLength = @_length
    if oldLength != newLength
      @buffer.resize newLength
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



##################
### Observable ###
##################

# Observable is a wrapper over any buffer-like object allowing to subscribe to
# changes.

export class Observable
  @generateAccessors()

  ### Properties ###

  constructor: (@_buffer) -> 
    @_onChanged = EventDispatcher.create()
  @getter 'length'   , -> @buffer.length
  @getter 'rawArray' , -> @buffer.rawArray


  ### Read / Write ###

  read:         (ix)  -> @buffer.read         ix
  readMultiple: (ixs) -> @buffer.readMultiple ixs 
  
  write: (ix, v) -> 
    @buffer.write ix, v
    @__onChanged ix
  
  writeMultiple: (ixs, vs) ->
    @buffer.writeMultiple ixs, vs 
    @__onChangedMultiple ixs

  set: (buffer, offset=0) ->
    @buffer.set buffer, offset
    @__onChangedRange offset, buffer.length


  ### Size Management ###

  resize: (newLength) ->
    oldLength = @_length
    if oldLength != newLength
      @buffer.resize newLength
      @__onResized oldLength, newLength


  ### Events ###  

  __onResized: (oldSize, newSize) ->
  __onChanged: (ix) -> @onChanged.dispatch ix

  __onChangedMultiple: (ixs) ->
    for ix in ixs
      @__onChanged ix
  
  __onChangedRange: (offset, length) ->
    for ix in [offset ... offset + length]
      @__onChanged ix


