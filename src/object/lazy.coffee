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
    @_isDirty = false
  @getter 'onSet'   , -> @_onSet
  @getter 'onUnset' , -> @_onUnset
  @getter 'isDirty' , -> @_isDirty

  set: ->
    if not @isDirty
      @_isDirty = true
      @onSet.dispatch()

  unset: ->
    if @isDirty
      @_isDirty = false
      @onUnset.dispatch()



###################
### ListManager ###
###################

export class ListManager extends Manager
  constructor: ->
    super() 
    @_elems = []
  @getter 'elems', -> @_elems

  set: (elem) ->
    @_elems.push elem
    super.set()

  unset: ->
    @_elems = []
    super.unset()



###########################
### HierarchicalManager ###
###########################

export class HierarchicalManager extends ListManager
  unset: ->
    for elem in @elems
      elem.dirty.unset()
    super.unset()



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
    if @isDirty
      if      ix > @range.max then @range.max = ix
      else if ix < @range.min then @range.min = ix
    else
      @_range.min = ix
      @_range.max = ix
      @set()

  setRange: (offset, length) ->
    min = offset
    max = min + length - 1
    if @isDirty
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
    @_dirty = Config.get('lazyManager',cfg) || new Manager 
    @logger.ifEnabled =>
      @_dirty.onSet.addEventListener   => @logger.info "Dirty flag set"
      @_dirty.onUnset.addEventListener => @logger.info "Dirty flag unset"
  @getter 'dirty', -> @_dirty
    