import * as Config          from 'basegl/object/config'
import * as EventDispatcher from 'basegl/event/dispatcher'
import * as Logged          from 'basegl/object/logged'


###############
### Manager ###
###############

export class Manager
  constructor: () ->
    @_onSet   = EventDispatcher.create() 
    @_onUnset = EventDispatcher.create() 
    @_isSet   = false
  @getter 'onSet'   , -> @_onSet
  @getter 'onUnset' , -> @_onUnset
  @getter 'isSet' , -> @_isSet

  set: ->
    if not @isSet
      @_isSet = true
      @onSet.dispatch()

  unset: ->
    if @isSet
      @_isSet = false
      @onUnset.dispatch()



###################
### ListManager ###
###################

export class ListManager extends Manager
  constructor: ->
    super() 
    @_elems = []
  @getter 'elems', -> @_elems

  setElem: (elem) ->
    @_elems.push elem
    @set()

  unset: ->
    @_elems = []
    super.unset()



###########################
### HierarchicalManager ###
###########################

export class HierarchicalManager extends ListManager

  constructor: (@childAccessor) ->
    super()
    if not @childAccessor
      @childAccessor = (a) -> a

  unset: ->
    dirtyElems = @elems
    super.unset()
    for elem in dirtyElems
      @childAccessor(elem).dirty.unset()



#####################
### RangedManager ###
#####################

export class RangedManager extends Manager
  constructor: ->
    super()
    @_range = 
      min: null
      max: null
  @getter 'range', -> @_range

  setIndex: (ix) ->
    if @isSet
      if      ix > @range.max then @range.max = ix
      else if ix < @range.min then @range.min = ix
    else
      @_range.min = ix
      @_range.max = ix
      @set()

  setRange: (offset, length) ->
    min = offset
    max = min + length - 1
    if @isSet
      if max > @range.max then @range.max = max
      if min < @range.min then @range.min = min
    else
      @_range.min = min
      @_range.max = max
      @set()



##############
### Object ###
##############

export class Object extends Logged.Logged
  constructor: (cfg={}) ->
    super cfg
    @_dirty = cfg.lazyManager || new Manager 
    @logger.ifEnabled =>
      @_dirty.onSet.addEventListener   => @logger.info "Dirty flag set"
      @_dirty.onUnset.addEventListener => @logger.info "Dirty flag unset"
  @getter 'dirty', -> @_dirty
    