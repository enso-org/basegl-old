import * as Config   from 'basegl/object/config'
import * as Unique   from 'basegl/object/unique'
import * as Property from 'basegl/object/Property'

import {logger} from 'logger'


##############
### Logged ###
##############

export class Logged
  @mixin Unique.Unique
  constructor: (cfg={}) ->
    @mixins.constructor()
    @_label  = cfg.label || "Unlabeled"
    @_label  = "#{@_label}.#{@id}"
    @_logger = logger.scoped @_label