#! /usr/local/bin/coffee

async = require 'async'
gpio = require 'pi-gpio'

outlet1 = 11
outlet2 = 12
outlet3 = 13
outlet4 = 15



openClose = (port, callback) ->
  async.series [
    (callback) ->
      console.log 'opening', port
      gpio.open port, 'output', callback

    (callback) ->
      console.log 'waiting..'
      setTimeout callback, 5000

    (callback) ->
      console.log 'setting to 1'
      gpio.write port, 1, callback


  ], ->
    console.log 'closing'
    gpio.close port, callback


openClose process.argv[2]

# async.series [
#   (callback) ->
#     openClose(11, callback)

#   (callback) ->
#     openClose(12, callback)

#   (callback) ->
#     openClose(13, callback)

#   (callback) ->
#     openClose(15, callback)
# ]
