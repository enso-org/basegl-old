import {Composable} from "basegl/object/Property"


##########################
### HierarchicalObject ###
##########################

export class HierarchicalObject extends Composable
  cons: (@src, children=[]) ->
    @_children = new Set
    @_parent   = null
    @addChildren children...

  @property 'parent', get: -> @_parent

  @getter 'children', -> @_children

  addChild: (a) ->
    @_children.add(a)
    a._parent = @src

  removeChild: (a) ->
    @_children.delete a
    a._parent = undefined

  addChildren: (children...) ->
    for child from children
      @addChild child

  dispose: ->
    @_children.forEach (child) ->
      child.dispose()
    @_children.clear()

  getParentChain: () ->
    lst = if @_parent? then @_parent.getParentChain() else []
    lst.push @
    lst
