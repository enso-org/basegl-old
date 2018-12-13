import * as M    from 'gl-matrix'
import * as Lazy from 'basegl/object/lazy'

import {EventObject} from 'basegl/display/object/event'
import {Vec3}        from 'basegl/data/vector'


#####################
### DisplayObject ###
#####################

# export POINTER_EVENTS =
#   INHERIT:  "inherit"
#   ENABLED:  "enabled"  # enable  for this element and its children
#   DISABLED: "disabled" # disable for this element and its children

# export styleMixin = -> @style = @mixin DisplayStyle
# export class DisplayStyle extends Composable
#   cons: () ->
#     @pointerEvents         = POINTER_EVENTS.INHERIT
#     @childrenPointerEvents = POINTER_EVENTS.INHERIT

export class Transform
  @mixin Lazy.LazyManager

  constructor: (children) ->
    @mixins.constructor()
    @__matrix  = M.mat4.create()
    @_origin   = M.mat4.create()
    @_position = Vec3.observableFrom [0,0,0]
    @_scale    = Vec3.observableFrom [1,1,1]
    @_rotation = Vec3.observableFrom [0,0,0]
    @_position.array.onChanged = => @dirty.set()
    @_scale.array.onChanged    = => @dirty.set()
    @_rotation.array.onChanged = => @dirty.set()

  @getter 'matrix' , -> @update(); @_matrix
  @setter 'origin' , (v) -> 
    @_origin = v
    @dirty.set()

  update: ->
    if @dirty.isSet
      @_matrix  = M.mat4.create()
      M.mat4.translate @_matrix , @_matrix , @position.xyz
      M.mat4.rotateX   @_matrix , @_matrix , @rotation.x
      M.mat4.rotateY   @_matrix , @_matrix , @rotation.y
      M.mat4.rotateZ   @_matrix , @_matrix , @rotation.z
      M.mat4.scale     @_matrix , @_matrix , @scale.xyz
      M.mat4.multiply  @_matrix , @_origin , @_matrix
      @dirty.unset()


export class DisplayObject extends EventObject
  @mixin Transform,
    whitelist: ['position', 'rotation', 'scale']

  constructor: (children) ->
    super()
    @mixins.constructor()
    @transform.dirty.onSet.addEventListener =>
      @forEach (child) =>
        child.transform.dirty.set()
    @onChildAdded.addEventListener (child) =>
      child.transform.dirty.set()

  update: ->
    if @transform.dirty.isSet
      if @parent
        @transform.origin = @parent.transform.matrix 
      else 
        @transform.origin = M.mat4.create()
      @transform.update()

export group = (elems) -> new DisplayObject elems


window.DisplayObject = DisplayObject
window.EventObject = EventObject


# export class DisplayObject extends EventObject
#   @mixin Lazy.LazyManager

#   constructor: (children) ->
#     super()
#     @mixins.constructor
#       label: "DisplayObject"

#     @__origin  = M.mat4.create()
#     @__xform   = M.mat4.create()
#     @_position = Vec3.observableFrom [0,0,0]
#     @_scale    = Vec3.observableFrom [1,1,1]
#     @_rotation = Vec3.observableFrom [0,0,0]
#     @_position.array.onChanged = => @dirty.set()
#     @_scale.array.onChanged    = => @dirty.set()
#     @_rotation.array.onChanged = => @dirty.set()
#     @dirty.onSet.addEventListener =>
#       @forEach (child) =>
#         child.dirty.set()
#     @onChildAdded.addEventListener (child) =>
#       child.dirty.set()

#   @getter 'xform'  , -> @update(); @_xform
#   @getter 'origin' , -> @update(); @_origin

#   update: ->
#     if @dirty.isSet
#       @_origin = if @parent then @parent.xform else M.mat4.create()
#       @_xform  = M.mat4.create()
#       M.mat4.translate @_xform , @_xform  , @position.xyz
#       M.mat4.rotateX   @_xform , @_xform  , @rotation.x
#       M.mat4.rotateY   @_xform , @_xform  , @rotation.y
#       M.mat4.rotateZ   @_xform , @_xform  , @rotation.z
#       M.mat4.scale     @_xform , @_xform  , @scale.xyz
#       M.mat4.multiply  @_xform , @_origin , @_xform
#       @dirty.unset()

# export group = (elems) -> new DisplayObject elems







# ##################
# ### Benchmarks ###
# ##################

# buildChain = ->
#   first   = new DisplayObject
#   current = first
#   last    = first
#   for i in [0...10]
#     last = new DisplayObject
#     current.addChild last
#     current = last
#   {first, last}

# buildChains = ->
#   firstList = []
#   lastList  = []
#   for i in [0...1000]
#     {first, last} = buildChain()
#     firstList.push first
#     lastList.push last
#   {firstList, lastList}

# {firstList, lastList} = buildChains()


# for i in [0 ... 10]
#   console.log "----- #{i} -----"
  
#   t1 = performance.now()
#   firstList.forEach (obj) -> 
#     obj.position.x += 1
#   t2 = performance.now()
#   console.log "Moving", (t2-t1)

#   t1 = performance.now()
#   firstList.forEach (obj) -> 
#     obj.position.x += 1
#   t2 = performance.now()
#   console.log "Moving", (t2-t1)

#   t1 = performance.now()
#   lastList.forEach (obj) ->
#     x = obj.xform
#   t2 = performance.now()
#   console.log "Updating", (t2-t1)

#   t1 = performance.now()
#   firstList.forEach (obj) -> 
#     obj.position.x += 1
#   t2 = performance.now()
#   console.log "Moving", (t2-t1)

#   t1 = performance.now()
#   lastList.forEach (obj) ->
#     x = obj.xform
#   t2 = performance.now()
#   console.log "Updating", (t2-t1)
