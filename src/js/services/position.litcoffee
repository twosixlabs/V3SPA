    services = angular.module 'vespa.services'

    services.factory 'PositionManager', (SockJSService, $q, $cacheFactory)->

      class PositionMgr
        constructor: (@id)->

          @data = {}
          @retrieve()

        update: (data)=>
          changed = false
          @data ?= {}
          for k, v of data
            if @data[k] != v
              @data[k] = v
              changed = true

          if changed
            @percolate()

Percolate changes to the server

        percolate: =>
          d = $q.defer()

          updates = _.clone @data
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
              @data = result.payload
              d.resolve result.payload

          return d.promise


When the factory function is called, actually return an object that
can be used to retrieve positions. Retrieve a cached manager if possible.

      cache = $cacheFactory('position_managers', {capacity: 5})

      return (id)->
        manager = cache.get(id)
        if not manager?
          manager = new PositionMgr(id)
          cache.put(id, manager)
        return manager
