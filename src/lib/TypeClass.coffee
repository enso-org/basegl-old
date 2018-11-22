
tcID = 0

getNextID = () ->
  id = tcID
  tcID += 1
  id

tcName = (i) -> '__typeclass__' + i

export define = (name='unnamed') ->
  id   = getNextID()
  prop = tcName id
  func = (obj, args...) ->
    dst = obj[prop]
    if not dst
      throw {msg: "Object does not implement `#{name}` type class.", obj}
    dst.call obj, args...
  func.id = id
  func.tc = name
  func

export define2 = (name = 'unnamed') ->
  id = getNextID()
  func = (obj) -> 
    tc  = obj.__typeclass__
    # TODO: remove in production mode
    if not tc
      throw {msg: "Object does not implement `#{name}` type class.", obj}
    dst = tc[id]
    # TODO: remove in production mode
    if not dst
      throw {msg: "Object does not implement `#{name}` type class.", obj}
    dst
  func.id = id
  func
  

export implement = (obj, tc, f) ->
  obj.prototype[tcName tc.id] = f

export implement2 = (obj, tc, val) ->
  if obj.prototype.__typeclass__ == undefined
    obj.prototype.__typeclass__ = {}
  obj.prototype.__typeclass__[tc.id] = val

export implementStatic2 = (obj, tc, val) ->
  if obj.prototype.__typeclass__ == undefined
    obj.prototype.__typeclass__ = {}
  obj.prototype.__typeclass__[tc.id] = val
  if obj.__typeclass__ == undefined
    obj.__typeclass__ = {}
  obj.__typeclass__[tc.id] = val
