
import * as Property        from 'basegl/object/Property'
import {HierarchicalObject} from 'basegl/display/object/hierarchical'


defineValue = Property.defineValue

export class EventObject extends HierarchicalObject
  @generateAccessors()

  ### Initialization ###

  constructor: () ->
    super()
    @__captureListeners = {}
    @__bubbleListeners  = {}


  ### Listener management ###

  addEventListener: (name, listener, useCapture) ->
    listenerMap = @_getListenerMap useCapture
    listeners   = listenerMap[name] ? new Set()
    listeners.add listener
    listenerMap[name] = listeners 

  removeEventListener: (name, listener, useCapture) ->
    listenerMap = @_getListenerMap useCapture
    listeners   = listenerMap[name]
    if listeners?
      listeners.delete listener
      if listeners.size == 0 
        delete listenerMap[name]

  _getListenerMap: (useCapture=false) ->
    if useCapture then @_captureListeners else @_bubbleListeners


  ### Event dispatching ###

  dispatchEvent: (e) ->
    chain  = @parentChain()
    rchain = chain.slice().reverse()
    state  = {stop: false, stopImmediate: false}
    defineValue e, 'target'                   , @
    defineValue e, 'path'                     , rchain
    defineValue e, 'stopPropagation'          , -> state.stop          = true
    defineValue e, 'stopImmediatePropagation' , -> state.stopImmediate = true

    dispatchPhase = (chain, phase, listenerMapName) ->
      defineValue e, 'eventPhase', phase
      for el in chain
        defineValue e, 'currentTarget', el
        fset = el[listenerMapName][e.type]
        if fset? then fset.forEach (f) ->
          f e
          if state.stopImmediate 
            return (!e.defaultPrevented)
        if state.stop || not e.bubbles 
          return (!e.defaultPrevented)

    dispatchPhase chain,  e.CAPTURING_PHASE, '_captureListeners'
    if state.stop || state.stopImmediate then return (!e.defaultPrevented)
    dispatchPhase rchain, e.BUBBLING_PHASE,  '_bubbleListeners'

  captureBy: (f) ->
    chain  = @parentChain()
    target = null
    for el in chain
      if f el then target = el
    return target

export disableBubbling = (e) -> defineValue e, 'bubbles', false
