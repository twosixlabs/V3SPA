    services = angular.module 'vespa.services'

    services.factory 'PositionManager', (SockJSService, $q, $cacheFactory)->

      class PositionMgr
        constructor: (@id, defaults = {}, @local = {})->

          @observers = {}

          @percolate = _.throttle @_percolate, 1000, leading: false

          @data = defaults

          @loading = false

        bind: (event, func, _this)->
          @observers[event] ?= []
          @observers[event].push([ _this, func ])

        notify: (event)->
          for observer in @observers[event] or []
            do (observer)=>
              observer[1].apply observer[0], [@]

        get: (key)->
          return @data[key]

        set: (obj, propagate=true)->
          @update(obj, propagate)

        update: (data, propagate=true)=>
          changed = []
          @data ?= {}
          for k, v of data
            if @data[k] != v
              @data[k] = v
              changed.push k

              # if it's a local only, don't mark changed.
              if @local != true and not _.contains @local, k
                nonlocal_changed = true

          if changed.length > 0 and propagate
            if nonlocal_changed and not @d
              @percolate()

            @notify('change')
          return changed

Percolate changes to the server

        _percolate: =>

          d = $q.defer()

          updates = _.omit @data, if @local != true then @local else {}
          updates.id = @id
          updates._id = @data._id

          req = 
            domain: 'location'
            request: 'update'
            payload: updates

          console.log "#{@id} sent position"

          SockJSService.send req, (result)=>
            if result.error 
              d.reject result.payload
            else
              d.resolve result.payload

          return d.promise

        retrieve: ()=>
          if @d # currently loading
            return @d.promise

          @d = $q.defer()

          req = 
            domain: 'location'
            request: 'get'
            payload: 
              id: @id

          SockJSService.send req, (result)=>
            if result.error 
              @d.reject result.payload
              @d = null
            else
              if result.payload? and not _.isEmpty(result.payload)
                console.log "#{@id} retrieved new position from server", result.payload
                # The server updated the location. Update the data
                # and notify anyone who might care.
                _.extend @data, result.payload
                @d.resolve
                  remote_update: true
                  data: @
                @d = null
              else if @local != true
                console.log "#{@id} retrieved position but will use default"
                # the defaults were better, send them to the server
                # use _percolate because we want to send immediately
                # and get the object id back so we can reference it properly.
                percolated = @_percolate()
                percolated.then (data)=>
                  _.extend @data, data

                @d.resolve
                  remote_update: false
                  data: @
                @d = null

          return @d.promise

When the factory function is called, actually return an object that
can be used to retrieve positions. Retrieve a cached manager if possible.

      cache = $cacheFactory('position_managers', {capacity: 50})

      return (id, defaults, locals)->
        manager = cache.get(id)
        if not manager?
          manager = new PositionMgr(id, defaults, locals)
          cache.put(id, manager)
        return manager
