#! /usr/local/bin/coffee

async = require 'async'
gpio = require 'pi-gpio'

[..., pin] = process.argv

async.waterfall [
  (callback) ->
    gpio.open pin, 'input pulldown', callback

  (callback) ->
    gpio.read pin, callback

  (value, callback) ->
    console.log "value of pin is #{value}"
    callback()

], ->
  gpio.close pin

