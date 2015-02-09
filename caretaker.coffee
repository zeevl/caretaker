async = require 'async'
gpio = require 'pi-gpio'

port1 = 11
port2 = 12
port3 = 13
port4 = 15

powerOn = (port, cb) ->
  console.log 'opening', port
  gpio.open port, 'output', cb

powerOff = (port, cb) ->
  console.log 'closing', port
  gpio.write port, 1, ->
    gpio.close port
    cb?()

port = port1

async.series [ 
  (cb) ->
    console.log 'opening', port
    gpio.open port, 'output', ->
      setTimeout cb, 10000
  , (cb) ->
    console.log 'writing 0'
    gpio.write port, 0, ->
      setTimeout cb, 10000
  , (cb) ->
    console.log 'writing 1'
    gpio.write port, 1, ->
      setTimeout cb, 10000
  , (cb) ->
    console.log 'closing'
    gpio.close port
    cb()
]


# powerOn port, ->
#   setTimeout (-> powerOff port), 30000

