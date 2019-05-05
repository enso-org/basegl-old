import * as Config          from 'basegl/object/config'
import * as Logged          from 'basegl/object/logged'
import * as Property        from 'basegl/object/Property'
import {EventDispatcher} from 'basegl/event/dispatcher'


###############
### Manager ###
###############

export class Manager
  @generateAccessors()
  constructor: () ->
    @_onSet   = new EventDispatcher 
    @_onUnset = new EventDispatcher 
    @_isSet   = false

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

export class ListManager
  @mixin Manager
  constructor: ->
    @mixins.constructor()
    @_elems = []

  setElem: (elem) ->
    @_elems.push elem
    @set()

  unset: ->
    @_elems = []
    @_manager.unset()



###########################
### HierarchicalManager ###
###########################

export class HierarchicalManager
  @mixin ListManager

  constructor: (@childAccessor) ->
    @mixins.constructor()
    if not @childAccessor
      @childAccessor = (a) -> a

  unset: ->
    dirtyElems = @elems
    @_listManager.unset()
    for elem in dirtyElems
      @childAccessor(elem).dirty.unset()



#####################
### RangedManager ###
#####################

export class RangedManager
  @mixin Manager
  constructor: ->
    @mixins.constructor()
    @_range = 
      min: null
      max: null

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

export class LazyManager
  @mixin Logged.Logged
  constructor: (cfg={}) ->
    @mixins.constructor cfg
    @_dirty = cfg.lazyManager || new Manager 
    @logger.ifEnabled =>
      @_dirty.onSet.addEventListener   => @logger.info "Dirty flag set"
      @_dirty.onUnset.addEventListener => @logger.info "Dirty flag unset"
    
