import * as Config from 'basegl/object/config'
import * as Unique from 'basegl/object/unique'

import {logger} from 'logger'


##############
### Logged ###
##############

export class Logged extends Unique.Unique
  constructor: (cfg={}) ->
    super()
    @_label  = cfg.label || "#{@constructor.name}.#{@id}"
    @_logger = logger.scoped @_label
  @getter 'label'  , -> @_label
  @getter 'logger' , -> @_logger