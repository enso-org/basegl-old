
import * as Config   from 'basegl/object/config'
import * as Lazy     from 'basegl/object/lazy'
import * as Variable from 'basegl/display/symbol/3D/geometry/variable'


################
### Geometry ###
################

export class Geometry extends Lazy.Object

  ### Initialization ###

  constructor: (cfg) ->
    label = cfg.label || "Unnamed"
    super
      label       : "Geometry.#{label}"
      lazyManager : new Lazy.HierarchicalManager 
    @dirty.childAccessor = (name) => @scope[name]
    
    @logger.group 'Initialization', =>
      @_scope = {}
      @_initScopes cfg

  @getter 'scope', -> @_scope

  _initScopes: (cfg) -> 
    scopes = 
      point    : Variable.AttributeScope
      # polygon  : TODO (triangles?)
      instance : Variable.AttributeScope
      object   : Variable.UniformScope
      # global   : TODO (shared between objects)

    for name,cons of scopes
      do (name,cons) =>
        label = "#{@label}.#{name}"
        data  = cfg[name]
        @logger.group "Initializing #{name} scope", =>
          scope         = new cons {label, data}
          @_scope[name] = scope
          @[name]       = scope 
          scope.dirty.onSet.addEventListener =>
            @dirty.setElem name


export create = (args...) -> new Geometry args...