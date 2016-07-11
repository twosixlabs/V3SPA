    mod = angular.module 'vespa.services'


A service designed to encapulate all of the data interaction for handling
policies. Responsible for uncompressing jsonh objects, making queries.

    mod.service 'WSUtils',
      class WSUtils
        constructor: (@VespaLogger, @$rootScope,
        @SockJSService, @$q, @$timeout) ->

          # Probably don't need to maintain any state

Send a request to the server to fetch the raw policy and return the JSON parsed
version of the policy.

        fetch_condensed_graph: (id) =>
          deferred = @$q.defer()

          req =
            domain: 'raw'
            request: 'fetch_condensed_graph'
            payload:
              policy: id

          @SockJSService.send req, (result)=>
            if result.error  # Service error

              $.growl(
                title: "Error"
                message: result.payload
              ,
                type: 'danger'
              )

              deferred.reject result.payload

            else  # valid response. Must parse
              json = JSON.parse result.payload

              @uncompress_condensed(json.parameterized.condensed, id)

              deferred.resolve json

          return deferred.promise

Send a request to the server to fetch the raw policy and return the JSON parsed
version of the policy.

        fetch_raw_graph: (id) =>
          deferred = @$q.defer()

          req =
            domain: 'raw'
            request: 'fetch_raw_graph'
            payload:
              policy: id

          @SockJSService.send req, (result)=>
            if result.error  # Service error

              $.growl(
                title: "Error"
                message: result.payload
              ,
                type: 'danger'
              )

              deferred.reject result.payload

            else  # valid response. Must parse
              json = JSON.parse result.payload

              @uncompress_raw(json.parameterized.raw, id)

              deferred.resolve json

          return deferred.promise

Expand the raw policy nodes and links from succinct to verbose style.

        uncompress_raw: (json) =>
          # Parse the jsonh format into regular JSON objects
          json.nodes = jsonh.parse json.nodes
          json.links = jsonh.parse json.links

          # Confirm existence of abbreviated object keys, then expand them
          if json?.nodes? and
          't' of json.nodes[0] and
          'n' of json.nodes[0]
            
            typeMap =
              s: 'subject'
              o: 'object'
              c: 'class'
              p: 'perm'
            
            nodes = json.nodes.map (n) =>
              'type': typeMap[n.t]
              'name': n.n
              'selected': true
            json.nodes = nodes

          if json?.links? and
          't' of json.links[0] and
          's' of json.links[0]

            links = json.links.map (l) =>
              'target': nodes[l.t]
              'source': nodes[l.s]
            json.links = links

          return json

Expand the raw policy nodes and links from succinct to verbose style.

        uncompress_condensed: (json) =>
          # Parse the jsonh format into regular JSON objects
          json.nodes = jsonh.parse json.nodes
          json.links = jsonh.parse json.links

          # Confirm existence of abbreviated object keys, then expand them
          if json.nodes?[0]?.n and
          json?.links?[0]?.hasOwnProperty('t') and
          json?.links?[0]?.hasOwnProperty('s')
            
            json.nodes = json.nodes.map (n) ->
              'name': n.n
              'selected': true

            json.links = json.links.map (l) ->
              'target': json.nodes[l.t]
              'source': json.nodes[l.s]
              'perm': l.p

          return json