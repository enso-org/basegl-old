export class IdxPool
  constructor: (start=0) ->
    @_next = start
    @_free = []

  reserve: ->
    idx = @_free.shift()
    if not idx?
      idx = @_next
      @_next += 1
    idx

  dispose: (i) ->
    @_free.unshift i
