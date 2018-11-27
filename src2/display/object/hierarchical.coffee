import * as Property        from 'basegl/object/Property'
import * as EventDispatcher from 'basegl/event/dispatcher'

export class HierarchicalObject
  @generateAccessors()

  constructor: () ->
    @_onChildAdded   = EventDispatcher.create() 
    @_onChildRemoved = EventDispatcher.create() 
    @__children = new Set
    @_parent    = null

  @setter 'parent' , (p) -> @._redirect p
  addChild         : (a) -> a._redirect @
  removeChild      : (a) -> a._redirect null

  _redirect: (newParent) ->
    if @parent
      @parent._children.delete @
      @parent.onChildRemoved.dispatch @
    @_parent = newParent
    if newParent
      newParent._children.add @
      newParent.onChildAdded.dispatch @

  addChildren: (children...) ->
    for child from children
      @addChild child

  forEach: (f) ->
    @_children.forEach f

  dispose: ->
    @forEach (child) ->
      child.dispose()
    @_children.clear()
    @parent?.removeChild @

  parentChain: () ->
    lst = if @_parent? then @_parent.parentChain() else []
    lst.push @
    lst