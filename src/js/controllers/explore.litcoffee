    vespaControllers = angular.module('vespaControllers')

    vespaControllers.controller 'exploreCtrl', ($scope, VespaLogger, WSUtils,
        IDEBackend, $timeout, $modal, PositionManager, RefPolicy, $q, SockJSService) ->

      # The 'outstanding' attribute is truthy when a policy is being loaded
      $scope.status = SockJSService.status

      $scope.sigma = new sigma(
        container: 'explore-container'
        settings:
          minNodeSize: 3
          maxNodeSize: 3
          minEdgeSize: 0.5
          maxEdgeSize: 0.5
          edgeColor: "default"
          defaultEdgeColor: "#555"
          labelThreshold: 10
          singleHover: true
          hideEdgesOnMove: true
          mouseZoomDuration: 0
          doubleClickZoomDuration: 0
      )

      $scope.statistics

      degreeChangeCallback = (extent) ->
        nodeDegree = (n) ->
          $scope.sigma.graph.degree(n.id) > extent[0] and
          $scope.sigma.graph.degree(n.id) < extent[1]
        $scope.nodeFilter.undo('node-degree')
        $scope.nodeFilter.nodesBy(nodeDegree, 'node-degree').apply()

      authorityChangeCallback = (extent) ->
        nodeAuthority = (n) ->
          $scope.statistics[n.id].authority > extent[0] and
          $scope.statistics[n.id].authority < extent[1]
        $scope.nodeFilter.undo('node-authority')
        $scope.nodeFilter.nodesBy(nodeAuthority, 'node-authority').apply()

      hubChangeCallback = (extent) ->
        nodeHub = (n) ->
          $scope.statistics[n.id].hub > extent[0] and
          $scope.statistics[n.id].hub < extent[1]
        $scope.nodeFilter.undo('node-hub')
        $scope.nodeFilter.nodesBy(nodeHub, 'node-hub').apply()

      $scope.filters =
        degreeRange: [0, 100]
        degreeChange: degreeChangeCallback
        authorityRange: [0, 100]
        authorityChange: authorityChangeCallback
        hubRange: [0, 100]
        hubChange: hubChangeCallback

      $scope.nodeFilter = sigma.plugins.filter($scope.sigma)

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

        nodeTypes = ["subj", "obj", "perm", "class"]
        N = 7000
        E = 50000
        graph =
          nodes: []
          edges: []

        for i in [0...N]
          graph.nodes.push({
            id: 'n' + i
            label: 'Node ' + i
            x: Math.random()
            y: Math.random()
            size: 1
            type: nodeTypes[Math.floor(Math.random()*4)]
          })

        for i in [0...E]
          graph.edges.push({
            id: 'e' + i
            source: 'n' + (Math.random() * N | 0)
            target: 'n' + (Math.random() * N | 0)
            size: 1
          })

        graph.nodes = graph.nodes.map (n) ->
          n.color = nodeFillScale(n.type)
          return n


        $scope.sigma.graph.clear()
        $scope.sigma.graph.read(graph)
        $scope.statistics = $scope.sigma.graph.HITS()
        $scope.filters.degreeRange = d3.extent(graph.nodes, (n) -> $scope.sigma.graph.degree(n.id))
        $scope.filters.authorityRange = d3.extent(d3.values($scope.statistics), (n) -> n.authority)
        $scope.filters.hubRange = d3.extent(d3.values($scope.statistics), (n) -> n.hub)
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