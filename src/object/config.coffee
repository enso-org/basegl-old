##########################
### Extensible Configs ###
##########################

export get = (name, cfg) ->
  if cfg
    out = cfg[name]
    if out == undefined
      get name, cfg._
    else out
  else
    cfg

export extend = (base, ext) -> 
  ext._ = base
  ext