    mod = angular.module('vespa.services')

    mod.service 'RefPolicy',
      class RefPolicyImpl
        constructor: (@VespaLogger, @SockJSService, @$q, @$timeout)->

          @uploader_running = false
          @chunks_to_upload = []
          @current = null
          @_deferred_load = null
          @loading = null

        promise: =>
          if @loading?
            return @loading
          @_deferred_load = @$q.defer()

          # If promise comes back, no matter what the
          # result, make this variable null
          @_deferred_load.promise['finally'] =>
            @_deferred_load = null

          return @_deferred_load.promise

        load: (id)=>
          if @current?.id == id
            return

          deferred = @_deferred_load || @$q.defer()
          @loading = deferred.promise

          req = 
            domain: 'refpolicy'
            request: 'get'
            payload: id

          @SockJSService.send req, (data)=>
            if data.error?
              @current = null
              deferred.reject(@current)
              @loading = null
            else
              @current = data.payload
              @current._id = @current._id.$oid
              deferred.resolve(@current)
              @loading = null

          return @loading

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

