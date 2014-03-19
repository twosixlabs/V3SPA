    mod = angular.module('vespa.services')

    mod.service 'RefPolicy',
      class RefPolicyImpl
        constructor: (@VespaLogger, @SockJSService, @$q, @$timeout)->

          @uploader_running = false
          @chunks_to_upload = []
          @current = null
          @_current_promise = null

        current_refpol: =>
          deferred = @$q.defer()

          if @current
            deferred.resolve(@current)

          else if @_current_promise?
            @_current_promise.then (data)->
              deferred.resolve(data)
          else
            deferred.reject(null)

          return deferred.promise

        load: (id)=>
          deferred  = @$q.defer()
          @_current_promise = deferred.promise

          req = 
            domain: 'refpolicy'
            request: 'get'
            payload: id

          @SockJSService.send req, (data)=>
            if data.error?
              @current = null
              deferred.reject(@current)
            else
              @current = data.payload
              deferred.resolve(@current)

        current_as_select2: =>
          return null unless @current?
          ret =
            id: @current._id
            text: @current.id
            data: @current

        upload_chunk: (name, chunk, start, len, total)=>
          deferred = @$q.defer()

          req = 
            domain: 'refpolicy'
            request: 'upload_chunk'
            payload: 
              name: name
              data: chunk
              index: start
              length: len
              total: total

          @chunks_to_upload.push [req, deferred]

If this is the only thing in the queue, start the uploader

          if not @uploader_running
            @uploader_running = true
            @$timeout =>
              @_upload_chunks()

          return deferred.promise

        _upload_chunks: =>

          chunk = @chunks_to_upload.shift()
          req = chunk[0]
          deferred = chunk[1]

          @SockJSService.send req, (data)=>
            if data.error?
              deferred.reject(data.payload)
              @uploader_running = false
              @chunks_to_upload = []
            else
              deferred.resolve(data.payload)
              if @chunks_to_upload.length > 0
                @_upload_chunks()
              else
                @uploader_running = false


        list_modules: (oid)=>
          deferred = @$q.defer()

          req = 
            domain: 'refpolicy'
            request: 'find'
            payload: 
              criteria:
                _id: oid
                valid: true
              selection:
                id: true
                modules: true

          @SockJSService.send req, (data)->
            if data.error?
              deferred.reject(data.payload)
            else
              deferred.resolve(data.payload)

          return deferred.promise


        list: =>

          deferred = @$q.defer()

          req = 
            domain: 'refpolicy'
            request: 'find'
            payload: 
              criteria:
                valid: true
              selection:
                id: true


          @SockJSService.send req, (data)->
            if data.error?
              deferred.reject(data.payload)
            else
              deferred.resolve(data.payload)

          return deferred.promise

