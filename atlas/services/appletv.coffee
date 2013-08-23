mdns = require 'mdns'
express = require 'express'
request = require 'request'
{jspack} = require 'jspack'
async = require 'async'

PROMPT_ID = 1
SESSION_ID = 0


cmdBufferMap = {
  'up': [
    new Buffer("cmcc\x00\x00\x00\x01\x30cmbe\x00\x00\x00\x1DtouchDown&time=0&point=20,275"),
    new Buffer("cmcc\x00\x00\x00\x01\x30cmbe\x00\x00\x00\x1DtouchMove&time=1&point=20,270"),
    new Buffer("cmcc\x00\x00\x00\x01\x30cmbe\x00\x00\x00\x1DtouchMove&time=2&point=20,265"),
    new Buffer("cmcc\x00\x00\x00\x01\x30cmbe\x00\x00\x00\x1DtouchMove&time=3&point=20,260"),
    new Buffer("cmcc\x00\x00\x00\x01\x30cmbe\x00\x00\x00\x1DtouchMove&time=4&point=20,255"),
    new Buffer("cmcc\x00\x00\x00\x01\x30cmbe\x00\x00\x00\x1DtouchMove&time=5&point=20,250"),
    new Buffer("cmcc\x00\x00\x00\x01\x30cmbe\x00\x00\x00\x1BtouchUp&time=6&point=20,250")
  ],
  'down': [
    new Buffer("cmcc\x00\x00\x00\x01\x30cmbe\x00\x00\x00\x1DtouchDown&time=0&point=20,250"),
    new Buffer("cmcc\x00\x00\x00\x01\x30cmbe\x00\x00\x00\x1DtouchMove&time=1&point=20,255"),
    new Buffer("cmcc\x00\x00\x00\x01\x30cmbe\x00\x00\x00\x1DtouchMove&time=2&point=20,260"),
    new Buffer("cmcc\x00\x00\x00\x01\x30cmbe\x00\x00\x00\x1DtouchMove&time=3&point=20,265"),
    new Buffer("cmcc\x00\x00\x00\x01\x30cmbe\x00\x00\x00\x1DtouchMove&time=4&point=20,270"),     
    new Buffer("cmcc\x00\x00\x00\x01\x30cmbe\x00\x00\x00\x1DtouchMove&time=5&point=20,275"),
    new Buffer("cmcc\x00\x00\x00\x01\x30cmbe\x00\x00\x00\x1BtouchUp&time=6&point=20,275")
  ],
  'left': [
    new Buffer("cmcc\x00\x00\x00\x01\x30cmbe\x00\x00\x00\x1EtouchDown&time=0&point=75,100"),
    new Buffer("cmcc\x00\x00\x00\x01\x30cmbe\x00\x00\x00\x1DtouchMove&time=1&point=70,100"),
    new Buffer("cmcc\x00\x00\x00\x01\x30cmbe\x00\x00\x00\x1DtouchMove&time=3&point=65,100"),
    new Buffer("cmcc\x00\x00\x00\x01\x30cmbe\x00\x00\x00\x1DtouchMove&time=4&point=60,100"),
    new Buffer("cmcc\x00\x00\x00\x01\x30cmbe\x00\x00\x00\x1DtouchMove&time=5&point=55,100"),
    new Buffer("cmcc\x00\x00\x00\x01\x30cmbe\x00\x00\x00\x1DtouchMove&time=6&point=50,100"),
    new Buffer("cmcc\x00\x00\x00\x01\x30cmbe\x00\x00\x00\x1BtouchUp&time=7&point=50,100")
  ],
  'right': [
    new Buffer("cmcc\x00\x00\x00\x01\x30cmbe\x00\x00\x00\x1DtouchDown&time=0&point=50,100"),
    new Buffer("cmcc\x00\x00\x00\x01\x30cmbe\x00\x00\x00\x1DtouchMove&time=1&point=55,100"),
    new Buffer("cmcc\x00\x00\x00\x01\x30cmbe\x00\x00\x00\x1DtouchMove&time=3&point=60,100"),
    new Buffer("cmcc\x00\x00\x00\x01\x30cmbe\x00\x00\x00\x1DtouchMove&time=4&point=65,100"),
    new Buffer("cmcc\x00\x00\x00\x01\x30cmbe\x00\x00\x00\x1DtouchMove&time=5&point=70,100"),
    new Buffer("cmcc\x00\x00\x00\x01\x30cmbe\x00\x00\x00\x1DtouchMove&time=6&point=75,100"),
    new Buffer("cmcc\x00\x00\x00\x01\x30cmbe\x00\x00\x00\x1BtouchUp&time=7&point=75,100")
  ],
  'menu': [
    new Buffer("cmcc\x00\x00\x00\x01\x30cmbe\x00\x00\x00\x04menu")
  ],
  'select': [
    new Buffer("cmcc\x00\x00\x00\x01\x30cmbe\x00\x00\x00\x06select")
  ]
}


###
PARSER
###
class Parser

  constructor: (buffer) ->
    @buffer = buffer
    @location = 0

    @branches = /(casp|cmst|mlog|agal|mccr|mlcl|mdcl|mshl|mlit|abro|abar|agar|apso|caci|avdb|cmgt|aply|adbs)/
    @strings = /(minm|cann|cana|cang|canl|asaa|asal|asar|ascn|asgn|assa|assu|mcnm|mcna)/
    @ints = /(mstt|mlid)/
    @raws = /(canp)/

  parse: (listener, listenFor, handle) ->
    resp = {}
    progress = 0
    handle ?= @buffer.length

    until handle == 0
      key = @readString 4
      length = @readInt()
      handle -= 8 + length
      progress += 8 + length

      if @branches.test(key)
        branch = @parse listener, listenFor, length
        resp[key] = branch

        if listener?
          if listener.matcher(key).matches()
            listener.foundTag(key, branch)

      else if @ints.test(key)
        resp[key] = @readInt()
      else if @strings.test(key)
        resp[key] = @readString length
      else if @raws.test(key)
        resp[key] = @readRaw length
      else if length == 1 or length == 2 or length == 4 or length == 8
        resp[key] = @readRaw length
      else
        resp[key] = @readString length

    return resp

  readRaw: (length) ->
    loc = @location
    @location += length
    return @buffer.slice(loc, loc+length)

  readString: (length) ->
    loc = @location
    @location += length
    return @buffer.slice(loc, loc+length).toString()

  readInt: () ->
    loc = @location
    @location += 4
    return @buffer.readInt32BE(loc)

###
AppleTV Service
###
class AppleTVService

  constructor: ({ip, port, remote_guid}) ->
    @ip = ip or null
    @port = port or 1024
    @remote_guid = remote_guid or null

    # @adv = mdns.createAdvertisement mdns.tcp('_touch-remote'), @port,
    #   'txtRecord':
    #     'DvNm': 'Atlas'
    #     'RemV': 10000
    #     'DvTy': 'iPod'
    #     'RemN': 'Remote'
    #     'txtvers': 1
    #     'Pair': '0000000000000001'

    @initializeWebService()

  initializeWebService: ->
    @webService = express()

    @webService.configure =>
      @webService.use @webService.router

    @routes @webService

  routes: (app) ->
    app.get '/login', @login
    # app.get '/pair', @pair

    app.get '/control/:command', @controlHandler

  start: ->
    # console.log "Broadcasting iTunes Service"
    # @adv.start()

    console.log "Listening on port #{@port}"
    @webService.listen @port
  
  # ROUTES
  sendBuffers: (buffers, req, resp) ->
    headers = 
      'Viewer-Only-Client': 1
      'Client-DAAP-Version': '3.11'
      'Client-iTunes-Sharing-Version': '3.9'
      'Client-ATV-Sharing-Version': '1.2'
      'Accept': '*/*'
      'Content-Type': 'application/x-www-form-urlencoded'
      'Accept-Encoding': 'gzip'
      'User-Agent': 'Remote/599.20'
      'Pragma': 'no-cache'
      'Accept-Language': 'en-us'
  
    requests = []

    for bufferObj in buffers
      f = async.apply (buffer, callback) =>
        setTimeout =>
          headers['Content-Length'] = buffer.length
          uri = "http://#{@ip}:3689/ctrl-int/1/controlpromptentry?prompt-id=#{PROMPT_ID}&session-id=#{SESSION_ID}"
          PROMPT_ID++
          request
            'uri': uri
            'method': 'POST'
            'headers': headers
            'body': buffer
          , (err, response, body) ->
            callback(null, [buffer, response.statusCode])
        , 5
      , bufferObj
      requests.push f

    async.series requests

    resp.send "DONE"

  controlHandler: (req, resp)=>
    @sendBuffers cmdBufferMap[req.params.command], req, resp

  login: (req, resp) =>
    request
      'uri': "http://#{@ip}:3689/login?hasFP=1&hsgid=#{@remote_guid}"
      'method': null
      'headers': 
        'Viewer-Only-Client': 1
        'Client-Daap-Version': '3.10.1'
      'encoding': null
    , (err, response, body) ->
      p = new Parser body
      data = p.parse()
      SESSION_ID = data['mlog']['mlid']
      resp.send data

  ## THIS IS USELESS FOR APPLE TV BUT WORKS WITH ITUNES
  ###
  pair: (req, resp) ->
    values =
      'cmpg': '\x00\x00\x00\x00\x00\x00\x00\x02'
      'cmnm': 'devicename'
      'cmty': 'ipod'

    encoded = new Buffer('')
    for key, val of values
      encoded = Buffer.concat([encoded, new Buffer(key)])
      encoded = Buffer.concat([encoded, new Buffer(jspack.Pack('>i', [val.length]), 'binary')])
      encoded = Buffer.concat([encoded, new Buffer(val)])
    header = Buffer.concat [new Buffer('cmpa'), new Buffer(jspack.Pack('>i', [encoded.length]), 'binary')]
    encoded = Buffer.concat [header, encoded]

    resp.contentType 'text/html'
    resp.send encoded

    # resp.send("cmpa\x00\x00\x00.cmnm\x00\x00\x00\ndevicenamecmty\x00\x00\x00\x04ipodcmpg\x00\x00\x00\x08\x00\x00\x00\x00\x00\x00\x00\x01")
  ###

module.exports = AppleTVService