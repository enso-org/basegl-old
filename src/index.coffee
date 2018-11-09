import * as World  from 'basegl/display/World'
import * as _Math  from 'basegl/math/Common'

export world       = World.globalWorld
export fontManager = world.fontManager
export Math        = _Math

export expr = (args...) -> throw 'Do not use `basegl.expr` without `basegl-preprocessor`. If you use webpack, you can use `basegl-loader`.'

export {scene}                           from 'basegl/display/Scene'
export {symbol}                          from 'basegl/display/Symbol'
export {text, text2}                     from 'basegl/display/text/Font'
export {logger}                          from 'basegl/debug/logger'
