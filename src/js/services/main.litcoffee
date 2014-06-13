    socket = angular.module 'vespa.services', []

    socket.service 'TokenService', 
      class TokenGenerator
        constructor: ->
          @MAX = 9e15
          @MIN = 1e15
          @safegap = 1000
          @counter = @MIN

        generate: ->
          increment = Math.floor(@safegap*Math.random())
          if @counter > (@MAX - increment)
            @counter = @MIN
          @counter += increment
          return @counter.toString(36)


    socket.service 'VespaLogger',
      class VespaLogger
        constructor: (@$timeout)->
          @messages = []
          @hooks = []

        log: (domain, level, message)->
          msg = 
            timestamp: new Date()
            domain: domain
            level: level
            message: message.split('\n')

          if level == 'error'
              $.growl {title: 'Error', message: message}, 
                type: 'danger'

          @$timeout =>
            @messages.push(msg)
            if @messages.length > 10
              @messages.splice(0, @messages.length - 10)

        clear: ->
          @messages = []

    socket.service 'SockJSService',

      class WSService
        constructor: (@$timeout, @$rootScope, @TokenService, @VespaLogger)->
          @base_url = "http://#{location.host}/ws"
          @sock = SockJS(@base_url, null, {debug: true})
          @pending = []
          @callbacks = {}
          @msg_callbacks = {}

          @connection_info = 
            timeout: 1000
            last_attempt: new Date()

          @set_handlers()

          @status = 
            outstanding: 0

        reconnect: =>
          if @connection_info.timeout < 32000
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
              @VespaLogger.log 'server', 'error', msg.payload

Look for a message specific callback first, then try
general callbacks

            callback = @msg_callbacks[msg.label]
            if callback?
              @status.outstanding--
              #console.log "Have #{@status.outstanding} outstanding messages"
              @$rootScope.$apply ->
                callback(msg)
              return

            callback = @callbacks[msg.label]
            if not callback?
              console.log "Have no handler for message: #{msg.label}"
              return

            @status.outstanding--
            #console.log "Have #{@status.outstanding} outstanding messages"
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
            @status.outstanding++
            #console.log "Have #{@status.outstanding} outstanding messages"

          if @sock.readyState == 0
            console.log "Connection not yet established. Buffering message"
            @pending.push(data)
          else if @sock.readyState > 2
            throw new Error "Socket not connected"
          else
            @sock.send JSON.stringify(data)

A service which uses the HTML5 File API to read a selected file
and upload it to the server using the websocket endpoint specified

    socket.service 'AsyncFileReader', 
      class Reader
          constructor: (@$q, @VespaLogger, @$timeout) ->

          _read_file: (id, blob, type)->
              deferred = @$q.defer()
              reader = new FileReader()

              reader.onload = (event)->
                deferred.resolve([id, reader.result])

              reader.onerror = (event)->
                deferred.reject(event)

              if type == 'text'
                reader.readAsText(blob)
              else if type == 'binary'
                reader.readAsDataURL(blob)

              return deferred.promise

          read_binary_chunks: (file, callback, chunk=16384)->
            @have_error = false
            filesize = file.size

            read_chunk = (file, from)=>

              if @have_error
                console.log "Stopping FileReader because of errors"
                return

              if from + chunk > filesize
                chunk = filesize - from

              return if chunk <= 0

              blob = file.slice(from, from+chunk)

              promise = @_read_file(file.name, blob, 'binary')

              promise.then (done)->
                [nm, data] = done
                callback data.split(',')[1], from, chunk, filesize
                read_chunk(file, from + chunk)

            read_chunk(file, 0)

          read: (fileblobs, callback)=>

            promises = for key, blob of fileblobs
              @_read_file(key, blob, 'text')

            @$q.all(promises)
              .then(
                (data)=>
                  # Success
                  files = {}
                  for result in data
                    files[result[0]] = result[1]

Defer the callback so it doesnt happen in this digest cycle

                  @$timeout(
                    ->(callback(files))
                    0, false)
                  return

                (data)->
                  for reader, event in data
                    VespaLogger.log 'read', 'error', "Failed to read #{reader.name}"
              )
