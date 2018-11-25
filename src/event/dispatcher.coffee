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

export create = (args...) -> new EventDispatcher args...