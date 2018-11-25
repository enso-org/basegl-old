
import * as _ from 'lodash'

##########################
### Extensible Configs ###
##########################

export extend = (base, ext) ->
  Object.assign {}, base, ext

export defaultsDeep = (base, ext) ->
  newBase = Object.assign {}, base
  _defaultsDeep newBase, ext
  newBase

_defaultsDeep = (base, ext) -> 
  if ext.constructor == Object
    for k,v of ext
      if base[k] == undefined
        base[k] = v
      else _defaultsDeep base[k], v
