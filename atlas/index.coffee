AppleTVService = require './services/appletv'

module.exports = class Application

  constructor: ->
    @services = 
      'appletv': new AppleTVService 
        'ip': '192.168.1.141'
        'remote_guid': '00000000-0fea-c889-82f1-08ebd74c4aae'
        'port': 1024

  startServices: ->
    console.log "Starting Services..."
    for name, service of @services
      service.start()