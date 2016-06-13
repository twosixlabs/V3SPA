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

        fetch_raw_graph: (id) =>
          deferred = @$q.defer()

          req =
            domain: 'raw'
            request: 'fetch_graph'
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

              @uncompress(json, id)

              deferred.resolve json

          return deferred.promise

Expand the raw policy nodes and links from succinct to verbose style.

        uncompress: (json) =>
          # Parse the jsonh format into regular JSON objects
          json.parameterized.nodes = jsonh.parse json.parameterized.nodes
          json.parameterized.links = jsonh.parse json.parameterized.links

          # Confirm existence of abbreviated object keys, then expand them
          if json?.parameterized?.nodes? and
          't' of json.parameterized.nodes[0] and
          'n' of json.parameterized.nodes[0]
            
            typeMap =
              s: 'subject'
              o: 'object'
              c: 'class'
              p: 'perm'
            
            nodes = json.parameterized.nodes.map (n) =>
              'type': typeMap[n.t]
              'name': n.n
              'selected': true
            json.parameterized.nodes = nodes

          if json?.parameterized?.links? and
          't' of json.parameterized.links[0] and
          's' of json.parameterized.links[0]

            links = json.parameterized.links.map (l) =>
              'target': nodes[l.t]
              'source': nodes[l.s]
            json.parameterized.links = links

          return json