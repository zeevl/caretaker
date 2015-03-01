#! /usr/local/bin/coffee

sys = require 'sys'
{exec} = require 'child_process'
async = require 'async'
gpio = require 'pi-gpio'
dns = require 'dns'
moment = require 'moment'
Smtp = require './smtp'

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
      return done() unless connected
      exec 'sudo ntpd', done

  , callback


turnOffAll = (cb) ->
  async.parallel [
    (cb) ->
      powerOff port1, -> cb()
    (cb) ->
      powerOff port2, -> cb()
    (cb) ->
      powerOff port3, -> cb()
    (cb) ->
      powerOff port4, -> cb()
  ], cb

takePhotos = (cb) ->
  # start smtp server
  # wait for internet
  # email any file attachemtns

  smtp = new Smtp()

  async.parallel [
    (cb) ->
      powerOn port1, cb

    (cb) ->
      powerOn port3, cb

    (cb) ->
      smtp.once 'email-received', ->
        console.log 'received email'
        cb()

      smtp.starttServer()

    (cb) ->
      waitForInternet cb

  ], (err) ->
    console.log 'failed', err if err
    smtp.sendEmail cb


async.series [
  (cb) ->
    turnOffAll cb

  (cb) ->
    takePhotos cb

  (cb) ->
    if (new Date()).getHours() is 12
      turnOffAll(cb)
    else
      console.log 'turning off camera'
      powerOff port3, cb
], ->
  console.log 'Done!'

# smtp = new Smtp()
# smtp.sendEmail ->
#   console.log 'Done!'

