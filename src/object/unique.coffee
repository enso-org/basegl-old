##############
### Unique ###
##############

export class Unique
  @_nextID = 0
  @getID: ->
    id = @_nextID 
    @_nextID += 1
    id

  constructor: ->
    @_id = @constructor.getID()
  @getter 'id', -> @_id