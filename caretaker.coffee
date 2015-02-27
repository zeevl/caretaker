#! /usr/local/bin/coffee

async = require 'async'
gpio = require 'pi-gpio'
dns = require 'dns'
moment = require 'moment'

port1 = 11
port2 = 12
port3 = 13
port4 = 15

INET_TIMEOUT = 10

powerOn = (port, cb) ->
  console.log 'opening', port
  gpio.open port, 'output', cb

powerOff = (port, cb) ->
  console.log 'closing', port
  gpio.write port, 1, ->
    gpio.close port
    cb?()

waitForInternet = (callback) ->
  timeout = moment().add(INET_TIMEOUT, 'minutes')
  connected = false
  async.whilst ->
    not connected
  , (done) ->
    return done(new Error 'Timeout expired.') if Date.now() > timeout

    console.log 'checking..'
    dns.lookup 'www.google.com', (err) ->
      console.log 'lookup returned ', err
      connected = (err is null)
      done()

  , callback


async.series [
  (cb) ->
    powerOn port1, cb

  , (cb) ->
    waitForInternet cb

], (err) ->
  console.log 'CONNECTED!' unless err
  console.log 'failed', err if err
  powerOff port1, ->
    console.log 'Done.'


