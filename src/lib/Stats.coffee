import * as Statsjs from 'stats.js'


export class Stats
  constructor: () ->
    @_stats  = []
    @_active = true
    @domElement = document.createElement 'div'
    @domElement.classList.add("statsjs")

    for id in [0..2]
      widget = new Statsjs()
      widget.showPanel id
      @domElement.appendChild widget.dom
      widget.domElement.style.cssText = "position:absolute;top:0px;left:#{id*80}px;"
      @_stats.push widget
    @hide()

  hide:   -> @_active = false; @domElement.style.display = "none"
  show:   -> @_active = true;  @domElement.style.display = ""
  toggle: -> if @_active then @hide() else @show()

  measure: (f) ->
    for widget from @_stats
      widget.begin()
    out = f()
    for widget from @_stats
      widget.end()
    out

  run: (f) ->
    if @_active then @measure(f) else f()
