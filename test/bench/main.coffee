# import * as Benchmark from 'benchmark'

import _ from 'lodash';
import process from 'process';

benchmark = require('benchmark');
Benchmark = benchmark.runInContext({ _, process });
window.Benchmark = Benchmark;


### BENCHMARKS ###

# bench = ->
#   typedArrayRW = ->
#     arr = new Float32Array 1000
#     return
#       name: 'typedArrayRW'
#       fn: ->
#         for i in [1...1000]
#           arr[i] = arr[i-1]+1


#   bufferRW = ->
#     arr = new Float32Array 1000
#     arr = new Buffer arr
#     return
#       name: 'bufferRW'
#       fn: ->
#         for i in [1...1000]
#           arr.write i, (arr.read(i-1)+1)

#   suite = new Benchmark.Suite

#   suite
#     .add typedArrayRW()
#     .add bufferRW()
      
#     .on  'cycle', (event)  -> console.log(String(event.target))
#     .on  'complete',       -> console.log('Fastest is ' + this.filter('fastest').map('name'))
#     .run({ 'async': false })

# arr = new Float32Array 10
# for i in [1...10]
#   arr[i] = arr[i-1]+1
# console.log arr


# arr = new Float32Array 10
# arr = new Buffer arr
# for i in [1...10]
#   arr.write i, (arr.read(i-1)+1)
# console.log arr


# bench()

