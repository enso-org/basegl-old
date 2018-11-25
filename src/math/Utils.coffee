


# ### NOT USED RIGHT NOW ###

# gaussianConstant = 1 / Math.sqrt(2 * Math.PI)

# gaussian = (x) ->
#   mean  = 0
#   sigma = 1
#   x = (x - mean) / sigma
#   gaussianConstant * Math.exp(-0.5 * x * x) / sigma

# ngaussian_ = (lim, max, min) -> (x) ->
#   val  = gaussian (x*lim)
#   nval = (val - min) / (max - min)
#   nval

# ngaussianf = (lim) ->
#   max  = gaussian 0
#   min  = gaussian lim
#   ngaussian_(lim,max,min)

# ngaussian = ngaussianf 4


# ngaussian2D = (s, prec=10) ->
#   out = []
#   for x in [-s..s]
#     for y in [-s..s]
#       nx = Math.abs(x)/(s+1)
#       ny = Math.abs(y)/(s+1)
#       d  = Math.sqrt (nx*nx + ny*ny)
#       v  = if d > 1 then 0 else ngaussian(d)
#       out.push v
#   out = normArr out
#   rout = []
#   for el in out
#     rout.push roundTo(el,prec)
#   rout

# sumArr = (arr) ->
#   sum = 0
#   for el in arr
#     sum += el
#   sum

# normArr = (arr) ->
#   narr = []
#   sum  = sumArr arr
#   for el in arr
#     narr.push (el/sum)
#   narr

# roundTo = (i,n) ->
#   d = Math.pow(10,n)
#   Math.round(i * d)/d


# main = () ->
#   console.log '--->'
#   console.log ngaussian2D(1,3)
