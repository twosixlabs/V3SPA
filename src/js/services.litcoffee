    socket = angular.module 'vespa.socket', ['vespa']

    socket.service 'VespaLogger',
      class VespaLogger
        constructor: ()->
          @messages = []
          @hooks = []

        log: (domain, level, message)->
          msg = 
            timestamp: new Date().getTime()
            domain: domain
            level: level
            message: message
          @messages.push(msg)
          if @messages.length > 10
            @messages.splice(0, @messages.length - 10)

        clear: ->
          @messages = []

    socket.service 'SockJSService',

      class WSService
        constructor: (@$timeout, @$rootScope, @TokenService)->
          @base_url = "http://#{location.host}/ws"
          @sock = SockJS(@base_url, null, {debug: true})
          @pending = []
          @callbacks = {}
          @msg_callbacks = {}

          @connection_info = 
            timeout: 1000
            last_attempt: new Date()

          @set_handlers()

        reconnect: =>
          @connection_info.timeout = @connection_info.timeout * 2
          @connection_info.last_attempt = new Date()
          @sock = SockJS(@base_url, @protocols)
          @set_handlers()

        set_handlers: ->
          @sock.onopen = (event) =>
            console.log "Connection established. Sending #{@pending.length} buffered messages"
            for msg in @pending
              @sock.send(JSON.stringify(msg))

          @sock.onclose = (event)=>
            if new Date() - @connection_info.last_attempt > @connection_info.timeout
              @connection_info.timeout = 1000

            console.log "Connection lost. Will attempt reconnection in #{@connection_info.timeout / 1000} seconds"
            @$timeout @reconnect, @connection_info.timeout, false

          @sock.onmessage = (event) =>
            msg = JSON.parse(event.data)

            if msg.error
              callback = @msg_callbacks[msg.label]
              if callback?
                @$rootScope.$apply ->
                  callback(msg)
                delete @msg_callbacks[msg.label]
              return

Look for a message specific callback first, then try
general callbacks

            callback = @msg_callbacks[msg.label]
            if callback
              @$rootScope.$apply ->
                callback(msg)
              return

            callback = @callbacks[msg.label]
            if not callback?
              console.log "Have no handler for message: #{msg.label}"
              return

            @$rootScope.$apply ->
              callback(msg)

        on: (eventName, callback) =>
          @callbacks[eventName] = callback

        send: (data, response) =>

Sometimes we might want to handle a response specific to the requests.
We generate a token and do a callback specifically on that token.

          if response
            token = @TokenService.generate()
            @msg_callbacks[token] = response
            data.response_id = token

          if @sock.readyState == 0
            console.log "Connection not yet established. Buffering message"
            @pending.push(data)
          else if @sock.readyState > 2
            throw new Error "Socket not connected"
          else
            @sock.send JSON.stringify(data)
