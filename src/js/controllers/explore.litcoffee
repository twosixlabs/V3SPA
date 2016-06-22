    vespaControllers = angular.module('vespaControllers')

    vespaControllers.controller 'exploreCtrl', ($scope, VespaLogger, WSUtils,
        IDEBackend, $timeout, $modal, PositionManager, RefPolicy, $q, SockJSService) ->

      # The 'outstanding' attribute is truthy when a policy is being loaded
      $scope.status = SockJSService.status

      $scope.sigma = new sigma(
        container: 'explore-container'
        settings:
          minEdgeSize: 2
          maxEdgeSize: 2
          edgeColor: "default"
          defaultEdgeColor: "#555"
      )

      $scope.filters =
        degreeRange: [0, 100]
        degreeChange: (extent) -> console.log extent
        centralityRange: [0, 100]
        centralityChange: (extent) -> console.log extent

      $scope.controls =
        tab: 'nodesTab'
        linksVisible: false
        links:
          primary: true
          both: true
          comparison: true

      $scope.$watch 'controls.links', ((value) -> if value then redraw()), true
      $scope.$watch 'controls.linksVisible', ((value) -> if value == false or value == true then redraw())

      $scope.list_refpolicies = 
        query: (query)->
          promise = RefPolicy.list()
          promise.then(
            (policy_list)->
              dropdown = 
                results:  for d in policy_list
                  id: d._id.$oid
                  text: d.id
                  data: d

              query.callback(dropdown)
          )

      nodeFillScale = d3.scale.ordinal()
        .domain(["subj", "obj", "class", "perm"])
        .range(["#005892", "#ff7f0e", "#2ca02c", "#d62728"])

      $scope.update_view = (data) ->
        console.log "update_view"

        # Test sigma

        testGraph =
          nodes: [
            { id: "n0", label: "subj1", x: 0, y: 0, size: 5, type: "subj" },
            { id: "n1", label: "obj2", x: 10, y: 20, size: 5, type: "obj" },
            { id: "n2", label: "read", x: 20, y: 30, size: 5, type: "perm" },
            { id: "n3", label: "file", x: 30, y: 10, size: 5, type: "class" },
            { id: "n4", label: "ioctl", x: 35, y: 10, size: 5, type: "perm" },
            { id: "n5", label: "write", x: 25, y: 15, size: 5, type: "perm" },
            { id: "n6", label: "obj2", x: 10, y: 5, size: 5, type: "obj" },
            { id: "n7", label: "dir", x: 20, y: 15, size: 5, type: "class" },
          ]
          edges: [
            {id: "e0", source: "n0", target: "n1", size: 2}
            {id: "e1", source: "n0", target: "n2", size: 2}
            {id: "e2", source: "n2", target: "n3", size: 2}
            {id: "e3", source: "n2", target: "n6", size: 2}
            {id: "e4", source: "n5", target: "n3", size: 2}
            {id: "e5", source: "n6", target: "n7", size: 2}
            {id: "e6", source: "n7", target: "n3", size: 2}
            {id: "e7", source: "n1", target: "n4", size: 2}
          ]

        testGraph.nodes = testGraph.nodes.map (n) ->
          n.color = nodeFillScale(n.type)
          return n
        console.log testGraph.nodes[0]

        $scope.sigma.graph.clear()
        $scope.sigma.graph.read(testGraph)
        $scope.sigma.refresh()

      update = () ->
        console.log "update"

      redraw = () ->
        console.log "redraw"

      policy_load_callback = () ->
        console.log "policy_load_callback"

      IDEBackend.add_hook "json_changed", $scope.update_view
      IDEBackend.add_hook "policy_load", policy_load_callback
      
      $scope.$on "$destroy", ->
        IDEBackend.unhook "json_changed", $scope.update_view
        IDEBackend.unhook "policy_load", policy_load_callback

      $scope.policy = IDEBackend.current_policy

      # Load the Lobster data if it is not loaded
      if $scope.policy?._id and not $scope.policy.json?.lobster?
        IDEBackend.load_lobster()

      # If the Lobster data is already loaded, render the view
      if $scope.policy?.json?.lobster?
        $scope.update_view()

      # For testing, remove later
      $scope.update_view()