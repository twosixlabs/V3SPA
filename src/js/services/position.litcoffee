    services = angular.module 'vespa.services'

    services.factory 'PositionManager', (SockJSService, $q, $cacheFactory)->

      class PositionMgr
        constructor: (@id, defaults = {}, @local = {})->

          @observers = {}

          @percolate = _.throttle @_percolate, 1000, leading: false

          @data = defaults

          @loading = false
          #@retrieve().then =>
          #  @loading = false

        bind: (event, func, _this)->
          @observers[event] ?= []
          @observers[event].push([ _this, func ])

        notify: (event)->
          for observer in @observers[event] or []
            do (observer)=>
              observer[1].apply observer[0], [@]

        get: (key)->
          return @data[key]

        set: (obj)->
          @update(obj)

        update: (data)=>
          changed = false
          @data ?= {}
          for k, v of data
            if @data[k] != v
              @data[k] = v
              changed = true

              # if it's a local only, don't mark changed.
              if not _.contains @local, k
                nonlocal_changed = true

          if changed
            if nonlocal_changed and not @loading
              @percolate()

            @notify('change')
          return changed

Percolate changes to the server

        _percolate: =>

          d = $q.defer()

          updates = _.omit @data, @local
          updates.id = @id
          updates._id = @data._id

          req = 
            domain: 'location'
            request: 'update'
            payload: updates

          SockJSService.send req, (result)=>
            if result.error 
              d.reject result.payload
            else
              d.resolve result.payload

          return d.promise

        retrieve: ()=>
          d = $q.defer()

          req = 
            domain: 'location'
            request: 'get'
            payload: 
              id: @id

          SockJSService.send req, (result)=>
            if result.error 
              d.reject result.payload
            else
              console.log "#{@id} retrieved position from server"
              if result.payload? and not _.isEmpty(result.payload)
                # The server updated the location. Update the data
                # and notify anyone who might care.
                _.extend @data, result.payload
                @notify('change')
                d.resolve
                  remote_update: true
                  data: @
              else
                # the defaults were better, send them to the server
                # use _percolate because we want to send immediately
                # and get the object id back so we can reference it properly.
                percolated = @_percolate()
                percolated.then (data)=>
                  _.extend @data, data

                d.resolve
                  remote_update: false
                  data: @

          return d.promise

When the factory function is called, actually return an object that
can be used to retrieve positions. Retrieve a cached manager if possible.

      cache = $cacheFactory('position_managers', {capacity: 50})

      return (id, defaults, locals)->
        manager = cache.get(id)
        if not manager?
          manager = new PositionMgr(id, defaults, locals)
          cache.put(id, manager)
        return manager
