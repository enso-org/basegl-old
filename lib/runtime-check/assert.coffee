export assert = (ok, f) ->
  if not ok then f()