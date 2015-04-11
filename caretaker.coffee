#! /usr/local/bin/coffee

# require 'longjohn'
sys = require 'sys'
{exec} = require 'child_process'
async = require 'async'
gpio = require 'pi-gpio'
dns = require 'dns'
moment = require 'moment'
Smtp = require './smtp'

inetSwitch = 7
# internet
port1 = 11
port2 = 12
# router
port3 = 13
# cameras
port4 = 15

ports =
  internet: port1
  router: port3
  cameras: port4

INET_TIMEOUT = 10

powerOn = (port, cb) ->
  console.log 'opening', port
  gpio.open port, 'output', cb

powerOff = (port, cb) ->
  console.log 'closing', port
  gpio.write port, 1, ->
    gpio.close port
    cb?()

isInetSwitchOn = (cb) ->
  console.log 'checking inet switch'

  async.waterfall [
    (callback) ->
      gpio.open inetSwitch, 'input pulldown', callback

    (callback) ->
      gpio.read inetSwitch, callback

    (value, callback) ->
      console.log "inet switch: #{value}"
      gpio.close inetSwitch, (err) ->
        callback err, value
  ], cb

turnOnInternet = (callback) ->
  async.auto
    inet: (cb) ->
      powerOn ports.internet, -> cb()

    router: (cb) ->
      powerOn ports.router, -> cb()

    wait: ['inet', 'router', (cb) ->
      waitForInternet cb
    ]
  , ->
    callback()

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

  , (err) ->
    console.log 'waitForInternet done', err
    callback()

resetState = (callback) ->
  async.auto
    isInetOn: (cb) ->
      isInetSwitchOn (err, value) -> cb null, value

    turnOffInet: ['isInetOn', (cb, results) ->
      console.log "reset: isInetSwitchOn = #{results.isInetOn}"
      if results.isInetOn then return cb()
      powerOff ports.internet, -> cb()
    ]

    turnOffRouter: ['isInetOn', (cb, results) ->
      if results.isInetOn then return cb()
      powerOff ports.router, -> cb()
    ]

    turnOffCameras: (cb) ->
      powerOff ports.cameras, -> cb()

  , (err) ->
    callback()


takePhotos = (cb) ->
  # start smtp server
  # wait for internet
  # email any file attachemtns

  smtp = new Smtp()

  async.parallel [
    (cb) ->
      powerOn ports.cameras, cb

    (cb) ->
      smtp.once 'email-received', ->
        console.log 'received email'
        cb()

      smtp.startServer()

  ], (err) ->
    console.log 'failed', err if err
    smtp.sendEmail cb


takeSnapshot = (cb) ->
  console.log '*** TAKING SNAPSHOT ****'
  async.waterfall [
    (cb) ->
      console.log 'resetState'
      resetState cb

    (cb) ->
      console.log 'turnOnInternet'
      turnOnInternet cb

    (cb) ->
      console.log 'take photos'
      takePhotos cb

    (cb) ->
      console.log 'turn off internet'
      resetState cb

  ], (err) ->
    console.log 'Snapshot Done!', err
    cb()

# setInterval ->
#   snapshot()
# , 1000 * 60 * 30

takeSnapshot()
