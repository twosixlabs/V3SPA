    socket = angular.module 'vespa.socket', ['vespa']

    socket.service 'VespaLogger',
      class VespaLogger
        constructor: ->
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

    socket.factory 'SockJSService', ($rootScope, TokenService)->

      class WSService
        constructor: (base_url, protocols)->
          @sock = SockJS(base_url, protocols)
          @pending = []
          @callbacks = {}
          @msg_callbacks = {}

          @sock.onopen = (event) =>
            console.log "Connection established. Sending #{@pending.length} buffered messages"
            for msg in @pending
              @sock.send(JSON.stringify(msg))

          @sock.onmessage = (event) =>
            msg = JSON.parse(event.data)

            if msg.error
              callback = @msg_callbacks[msg.label]
              if callback?
                $rootScope.$apply ->
                  callback(msg)
                delete @msg_callbacks[msg.label]
              return

Look for a message specific callback first, then try
general callbacks

            callback = @msg_callbacks[msg.label]
            if callback
              $rootScope.$apply ->
                callback(msg)
              return

            callback = @callbacks[msg.label]
            if not callback?
              console.log "Have no handler for message: #{msg.label}"
              return

            $rootScope.$apply ->
              callback(msg)

        on: (eventName, callback) =>
          @callbacks[eventName] = callback

        send: (data, response) =>

Sometimes we might want to handle a response specific to the requests.
We generate a token and do a callback specifically on that token.

          if response
            token = TokenService.generate()
            @msg_callbacks[token] = response
            data.response_id = token

          if @sock.readyState == 0
            console.log "Connection not yet established. Buffering message"
            @pending.push(data)
          else if @sock.readyState > 2
            throw new Error "Socket not connected"
          else
            @sock.send JSON.stringify(data)

      return (url, proto)->
        new WSService(url, proto)
