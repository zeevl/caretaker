#! /usr/local/bin/coffee

# require 'longjohn'
sys = require 'sys'
{exec} = require 'child_process'
async = require 'async'
gpio = require 'pi-gpio'
dns = require 'dns'
moment = require 'moment'
Smtp = require './smtp'

CAMERA_TIME = 1000 * 60 * 2
SNAPSHOT_INTERVAL = 1000 * 60 * 10
SWITCH_POLL = 5007


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

portOn = {}

INET_TIMEOUT = 10

powerOn = (port, cb) ->
  return if portOn[port]
  console.log 'opening', port
  portOn[port] = true
  gpio.open port, 'output pulldown', cb

powerOff = (port, cb) ->
  return unless portOn[port]? is false
  portOn[port] = false
  console.log 'closing', port
  gpio.write port, 1, ->
    gpio.close port
    cb?()

isInetSwitchOn = (cb) ->
  async.waterfall [
    (callback) ->
      gpio.open inetSwitch, 'input pulldown', -> callback()

    (callback) ->
      gpio.read inetSwitch, callback

    (value, callback) ->
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
    callback()

resetState = (callback) ->
  async.auto
    isInetOn: (cb) ->
      isInetSwitchOn (err, value) -> cb null, value

    turnOffInet: ['isInetOn', (cb, results) ->
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
    if err then console.log 'reset: error', err
    callback()


takePhotos = (cb) ->
  async.series [
    (cb) ->
      powerOn ports.cameras, cb

    (cb) ->
      setTimeout cb, CAMERA_TIME

  ], cb

takeSnapshot = (callback) ->
  console.log '*** TAKING SNAPSHOT ****'
  async.waterfall [
    (cb) ->
      console.log 'resetState'
      resetState cb

    (..., cb) ->
      console.log 'turnOnInternet'
      turnOnInternet cb

    (..., cb) ->
      console.log 'take photos'
      takePhotos cb

    (..., cb) ->
      console.log 'turn off internet'
      resetState cb

  ], (err) ->
    console.log 'Snapshot Done!', err
    callback?()

updateSwitchState = ->
  async.auto
    isSwitchOn: (cb) ->
      isInetSwitchOn (err, value) -> cb null, value

    toggleInternet: ['isSwitchOn', (cb, results) ->
      if results.isSwitchOn
        powerOn ports.internet, -> cb()
      else
        powerOff ports.internet, -> cb()
    ]

    turnOffRouter: ['isSwitchOn', (cb, results) ->
      if results.isSwitchOn
        powerOn ports.router, -> cb()
      else
        powerOff ports.router, -> cb()
    ]

    turnOffCameras: (cb) ->
      powerOff ports.cameras, -> cb()


takeSnapshot()
updateSwitchState()

setInterval takeSnapshot, SNAPSHOT_INTERVAL
setInterval updateSwitchState, SWITCH_POLL
