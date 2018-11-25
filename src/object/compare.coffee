export shallowCompare = (a, b) ->
  if (a == b) then return true
  for k,v of a
    if b[k] != v then return false
  for k,v of b
    if a[k] != v then return false
  return true