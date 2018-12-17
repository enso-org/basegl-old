#######################
### EventDispatcher ###
#######################

class EventDispatcher
  constructor: -> 
    @_listeners = new Set
  
  addEventListener: (f) -> 
    @_listeners.add f
  
  removeEventListener: (f) -> 
    @_listeners.delete f
  
  dispatch: (xs...) -> 
    @_listeners.forEach (f) => f xs...

export eventDispatcher = (args...) -> new EventDispatcher args...

# deprecated
export create = (args...) -> new EventDispatcher args...



#################################
### SingleShotEventDispatcher ###
#################################

class SingleShotEventDispatcher
  @generateAccessors()

  constructor: ->
    @_dispatcher = new EventDispatcher
    @_args       = undefined

  addEventListener: (f) ->
    @dispatcher.addEventListener f
    if @args? then f @args...

  removeEventListener: (f) ->
    @dispatcher.removeEventListener f 

  dispatch: (xs...) ->
    @_args = xs
    @dispatcher.dispatch @args...

export singleShotEventDispatcher = (args...) -> 
  new SingleShotEventDispatcher args... 