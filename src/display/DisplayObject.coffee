import {eventDispatcherMixin}   from "basegl/event/EventDispatcher"
import {Vector}                 from "basegl/math/Vector"
import {mat4}                   from 'gl-matrix'
import {Composable, fieldMixin} from "basegl/object/Property"


#####################
### DisplayObject ###
#####################

export POINTER_EVENTS =
  INHERIT:  "inherit"
  ENABLED:  "enabled"  # enable  for this element and its children
  DISABLED: "disabled" # disable for this element and its children

export styleMixin = -> @style = @mixin DisplayStyle
export class DisplayStyle extends Composable
  cons: () ->
    @pointerEvents         = POINTER_EVENTS.INHERIT
    @childrenPointerEvents = POINTER_EVENTS.INHERIT

export class DisplayObject extends Composable
  cons: (children) ->
    @mixin styleMixin
    @mixin eventDispatcherMixin, @, children
    @_isDirty = true
    @origin   = mat4.create()
    @xform    = mat4.create()
    @position = new Vector [0,0,0], => @_onTransformed()
    @scale    = new Vector [1,1,1], => @_onTransformed()
    @rotation = new Vector [0,0,0], => @_onTransformed()
    @onTransformed = (->)

  setOrigin: (newOrigin) =>
    @origin = newOrigin
    @updateChildrenOrigin()

  updateChildrenOrigin: () =>
    @xform = mat4.create()
    mat4.scale     @xform, @xform, @scale.xyz
    mat4.rotateX   @xform, @xform, @rotation.x
    mat4.rotateY   @xform, @xform, @rotation.y
    mat4.rotateZ   @xform, @xform, @rotation.z
    mat4.translate @xform, @xform, @position.xyz
    mat4.multiply(@xform, @origin, @xform)

    @children.forEach (child) =>
      child.setOrigin @xform

  _onTransformed: () =>
    @_isDirty = true
    @onTransformed()

  update: () => if @isDirty
    # TODO: handle parents
    @xform = mat4.create()
    mat4.scale     @xform, @xform, @scale.xyz
    mat4.rotateX   @xform, @xform, @rotation.x
    mat4.rotateY   @xform, @xform, @rotation.y
    mat4.rotateZ   @xform, @xform, @rotation.z
    mat4.translate @xform, @xform, @position.xyz
    mat4.multiply(@xform, @origin, @xform)
    @_isDirty = false
    

export displayObjectMixin = fieldMixin DisplayObject


export group = (elems) -> new DisplayObject elems
