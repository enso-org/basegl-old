
import * as Config   from 'basegl/object/config'
import * as Lazy     from 'basegl/object/lazy'
import * as Variable from 'basegl/display/symbol/3D/geometry/variable'
import * as Vector   from 'basegl/data/vector'
import {vec2, vec3}  from 'basegl/data/vector'


################
### Geometry ###
################

export class Geometry # extends Lazy.LazyManager
  @mixin Lazy.LazyManager

  ### Initialization ###

  constructor: (cfg) ->
    label = cfg.label || "Unnamed"
    @mixins.constructor
      label       : "Geometry.#{label}"
      lazyManager : new Lazy.HierarchicalManager 

    @dirty.childAccessor = (name) => @scope[name]
    @logger.group 'Initialization', =>
      @_scope = {}
      @_initScopes cfg

  @getter 'id', -> throw "!!!"
    

  # @getter 'scope', -> @_scope

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



####################
### Basic shapes ###
####################

export rectangle = (cfg) ->
  width  = cfg.width  || 10
  height = cfg.height || 10
  w2     = width  / 2
  h2     = height / 2
  
  opts = 
    point:
      position: 
        usage : Variable.usage.static
        data  : [
          (vec3 -w2,  h2, 0) ,
          (vec3 -w2, -h2, 0) ,
          (vec3  w2,  h2, 0) ,
          (vec3  w2, -h2, 0) ]
      
      uv:
        usage : Variable.usage.static
        data  : [
          (vec2 0,1) ,
          (vec2 0,0) ,
          (vec2 1,1) ,
          (vec2 1,0) ]

  geoCfg = Config.defaultsDeep cfg, opts
  create geoCfg