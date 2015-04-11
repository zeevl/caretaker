_ = require 'lodash'
async = require 'async'
crypto = require 'crypto'
fs = require 'fs'
path = require 'path'
emailjs = require 'emailjs'
moment = require 'moment'
{SMTPServer} = require 'smtp-server'
{MailParser} = require 'mailparser'
{EventEmitter} = require 'events'

module.exports = class Smtp extends EventEmitter
  startServer: ->
    console.log 'Staring email server..'
    mailparser = new MailParser
      streamAttachments: true

    server = new SMTPServer
      secure: true
      onAuth: (auth, session, callback) ->
        console.log 'smtp onAuth'
        callback(null, user: 'steve')
      onData: (stream, session, callback) =>
        console.log 'smpt ondata', stream
        stream.pipe mailparser
        stream.on 'end', =>
          @emit 'email-received'
          callback()

    mailparser.on 'attachment', (attachment, mail) ->
      console.log attachment.generatedFileName

      output = fs.createWriteStream path.join __dirname, 'images', attachment.generatedFileName
      attachment.stream.pipe output

    server.on 'error', (err) ->
      console.log('Error occurred')
      console.log(err)

    server.listen 1337

  removeDupes: (done) ->
    console.log 'Removing dupes...'
    files = fs.readdirSync path.join __dirname, "images"
    hashes = []
    async.each files, (file, callback) ->
      fd = fs.createReadStream path.join __dirname, 'images', file
      hash = crypto.createHash 'sha1'
      hash.setEncoding = 'hex'

      fd.on 'end', ->
        hash.end()
        val = hash.read().toString()
        if val in hashes
          console.log 'Deleting dupe file', file
          fs.unlink path.join(__dirname, 'images', file), callback
        else
          hashes.push val
          callback()

      fd.pipe hash
    , done

  sendEmail: (done) ->
    console.log 'sending email..'
    @removeDupes ->
      files = fs.readdirSync "#{__dirname}/images"
      attachments = _.map files, (file) ->
        path: path.join __dirname, 'images', file
        name: file
        type: 'image/jpeg'
        inline: true

      console.log attachments

      email = emailjs.server.connect
        user: 'unclejimscabin@gmail.com'
        password: 'charli3pants'
        host: 'smtp.gmail.com'
        ssl: true

      message =
        subject: "Cabin Update #{moment().format 'MMMM Do YYYY, h:mm:ss a'}"
        from: 'unclejimscabin@gmail.com'
        to: 'unclejimscabin@gmail.com'
        text: 'Here\'s the latest..'
        attachment: attachments

      email.send message, (err, message) ->
        console.log err or message
        return done() if err
        for attachment in attachments
          fs.unlinkSync attachment.path

        done()


