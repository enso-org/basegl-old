import {Symbol}    from 'basegl/display/Symbol'
import {rect}      from 'basegl/display/Shape'
import * as Color  from 'basegl/display/Color'
import * as jsnext from '@luna-lang/jsnext'
import * as basegl from 'basegl'

## FIXME: refactor
bg        = (Color.hsl [40,0.08,0.09]).toRGB()
selectionColor = bg.mix (Color.hsl [50, 1, 0.6]), 0.8


############################
### ComponentBufferProxy ###
############################
# The ComponentBufferProxy object translates (x,y) coordinates to symbol reference (null if missing).
# It uses an `buffer` object containing symbolFamilyID, symbolID and shapeID values to determine
# which symbol to choose

export class ComponentBufferProxy
  constructor: (@scene, @buffer) ->
    @_resolved = []

  get: (x,y) ->
    offset = (@scene.height - y) * @scene.width
    idx    = offset + x
    a = @_resolved[idx]
    if a != undefined then return a

    idx4 = 4*idx
    symbolFamilyID = @buffer[idx4]
    symbolID       = @buffer[idx4+1]
    shapeID        = @buffer[idx4+2]
    symbol         = null
    if shapeID != 0
      family = @scene.model.lookupComponentFamily symbolFamilyID
      if family? then symbol = family.lookupComponent symbolID
    @_resolved[idx] = symbol
    symbol



################
### QuadTree ###
################
# Optimized for symbol lookup from big, underlying pixel id array

export class QuadTree
  constructor: (@width, @height, @_arr, @spread=1, @mul=1, @subtree=null, @lvl=0) ->

  buildParent: (size=2) ->
    xs = Math.ceil (@width  / size)
    ys = Math.ceil (@height / size)
    new QuadTree xs, ys, [], (@spread*size), size, @, (@lvl+1)

  buildParents: (size=2) ->
    depth = 0
    q = @
    while (q.width != 1) || (q.height != 1)
      depth += 1
      q = q.buildParent size
    q

  compute: (ix,iy) ->
    offset = iy*@width + ix
    out    = @_arr[offset]
    if out != undefined then return out

    out    = new Set
    xstart = @mul * ix
    ystart = @mul * iy
    yend   = ystart + @mul
    xend   = xstart + @mul
    if @lvl == 1
      y = ystart
      while y < yend
        x = xstart
        while x < xend
          out.add @subtree._arr.get(x,y)
          x += 1
        y += 1
    else
      y = ystart
      while y < yend
        x = xstart
        while x < xend
          @subtree.compute(x,y).forEach (el) => out.add el
          x += 1
        y += 1

    @_arr[offset] = out
    out


  sampleRect: (xmin, ymin, xmax, ymax) ->
    out = new Set

    if @lvl == 0
      y = ymin
      while y < ymax
        x = xmin
        while x < xmax
          out.add @_arr.get(x,y)
          x += 1
        y += 1
    else
      xstart  = Math.ceil  (xmin/@spread)
      ystart  = Math.ceil  (ymin/@spread)
      xend    = Math.floor (xmax/@spread)
      yend    = Math.floor (ymax/@spread)
      borderL = xstart * @spread - xmin
      borderT = ystart * @spread - ymin
      borderR = (xmax) - xend * @spread
      borderB = (ymax) - yend * @spread

      y = ystart
      while y < yend
        x = xstart
        while x < xend
          @compute(x,y).forEach (el) => out.add el
          x += 1
        y += 1

      subw = (xmax - xmin - borderL - borderR)
      if borderL then   (@subtree.sampleRect xmin           , ymin          , (xmin+borderL), ymax)           . forEach (el) => out.add el
      if borderR then   (@subtree.sampleRect (xmax-borderR) , ymin          , xmax          , ymax)           . forEach (el) => out.add el
      if subw > 0
        if borderT then (@subtree.sampleRect (xmin+borderL) , ymin          , (xmax-borderR), (ymin+borderT)) . forEach (el) => out.add el
        if borderB then (@subtree.sampleRect (xmin+borderL) , (ymax-borderB), (xmax-borderR), ymax)           . forEach (el) => out.add el

    out


### Tests ###

# testArr = \
#   [ 1 , 2 , 3 , 4 , 5
#   , 6 , 7 , 8 , 9 , 10
#   , 11, 12, 13, 14, 15
#   , 16, 17, 18, 19, 20
#   ]
# testArr.get = (x,y) -> testArr[y*5+x]
#
# qt = new QuadTree 5, 4, testArr
# qt2 = qt.buildParent()
# qt3 = qt2.buildParent()
#
# console.log '------ vvv ------'
# console.log (qt3.sampleRect 0,0,4,4)
# console.log '------ ^^^ ------'
# console.log (qt3.sampleRect 0,0,4,4)
# console.log '------ ^^^ ------'



###################
### BoxSelector ###
###################

export boxSelectorShape = basegl.expr ->
  cd   = selectionColor.copy()
  cd.a = 0.3
  rect('bbox.x', 'bbox.y').alignedTL.fill(cd)


export class BoxSelector
  constructor: (@scene, @callback=()->, @mode='quadtree', @benchmark=false) ->
    widgetDef = new Component boxSelectorShape
    widgetDef.bbox.xy = [0,0]
    widgetDef.variables.alpha = 1
    @widget = @scene.add widgetDef
    @widget.position.xy = [0,0]

    @scene.addEventListener 'mousedown', (e) =>
      if e.button != 0 then return
      @scene.requestIDScreenshot (buffer) =>
        cpb = new ComponentBufferProxy @scene, buffer
        qt  = new QuadTree(@scene.width, @scene.height, cpb).buildParent(10).buildParent(10) # using more than two layers doesnt increase the speec

        clickX = @scene.screenMouse.x
        clickY = @scene.screenMouse.y

        @widget.position.x = @scene.mouse.x
        @widget.position.y = -@scene.mouse.y
        @widget.click      = {x: @scene.mouse.x, y: @scene.mouse.y}
        @widget.bbox.xy    = [0,0]

        onMouseMove = (e) =>
          @widget.position.x =  (if @scene.mouse.x < @widget.click.x then @scene.mouse.x else @widget.click.x)
          @widget.position.y = -(if @scene.mouse.y < @widget.click.y then @scene.mouse.y else @widget.click.y)
          @widget.bbox.x = Math.abs(@scene.mouse.x - @widget.click.x)
          @widget.bbox.y = Math.abs(@scene.mouse.y - @widget.click.y)

          if clickX < @scene.screenMouse.x
            x0 = clickX
            x1 = @scene.screenMouse.x
          else
            x0 = @scene.screenMouse.x
            x1 = clickX

          if clickY < @scene.screenMouse.y
            y0 = clickY
            y1 = @scene.screenMouse.y
          else
            y0 = @scene.screenMouse.y
            y1 = clickY


          if @benchmark then t0 = performance.now();

          symbols = null

          if @mode == 'quadtree'
            symbols = qt.sampleRect x0, y0, x1, y1
            symbols.delete null
          else if @mode = 'bruteforce'
            symbols = new Set
            for y in [y0..y1]
              for x in [x0..x1]
                symbols.add cpb.get(x,y)

          if @benchmark
            t1 = performance.now();
            console.log "BoxSelector time: #{Math.round(t1-t0)} ms"

          @callback symbols


        window.addEventListener 'mousemove', onMouseMove
        window.addEventListener 'mouseup', (e) =>
          window.removeEventListener 'mousemove', onMouseMove
          @widget.position.xy = [0,0]
          @widget.bbox.xy     = [0,0]
