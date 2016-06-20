    vespaControllers = angular.module('vespaControllers')

    vespaControllers.controller 'exploreCtrl', ($scope, VespaLogger, WSUtils,
        IDEBackend, $timeout, $modal, PositionManager, RefPolicy, $q, SockJSService) ->

      # The 'outstanding' attribute is truthy when a policy is being loaded
      $scope.status = SockJSService.status

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

      width = 350
      height = 500

      $scope.update_view = (data) ->
        console.log "update_view"

        # Test sigma

        testGraph =
          nodes: [
            { id: "n0", label: "A", x: 0, y: 0, size: 5 },
            { id: "n1", label: "B", x: 10, y: 20, size: 5 },
            { id: "n2", label: "C", x: 20, y: 30, size: 5 },
            { id: "n3", label: "D", x: 30, y: 10, size: 5 },
          ]
          edges: [
            {id: "e0", source: "n0", target: "n1"}
            {id: "e1", source: "n0", target: "n2"}
            {id: "e2", source: "n2", target: "n3"}
          ]

        s = new sigma(
          graph: testGraph
          container: 'explore-container'
        )

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