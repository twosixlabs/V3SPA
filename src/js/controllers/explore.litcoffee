    vespaControllers = angular.module('vespaControllers')

    vespaControllers.controller 'exploreCtrl', ($scope, VespaLogger, WSUtils,
        IDEBackend, $timeout, $modal, PositionManager, RefPolicy, $q, SockJSService) ->

      # The 'outstanding' attribute is truthy when a policy is being loaded
      $scope.status = SockJSService.status

      $scope.sigma = new sigma(
        container: 'explore-container'
        settings:
          minNodeSize: 2
          maxNodeSize: 2
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
        nodeDegree = (extent) ->
          (n) ->
            $scope.sigma.graph.degree(n.id) >= extent[0] and
            $scope.sigma.graph.degree(n.id) <= extent[1]
        $scope.nodeFilter.undo('node-degree')
        $scope.nodeFilter.nodesBy(nodeDegree(extent), 'node-degree').apply()

      authorityChangeCallback = (extent) ->
        nodeAuthority = (extent) ->
          (n) ->
            $scope.statistics[n.id]? and
            $scope.statistics[n.id].authority >= extent[0] and
            $scope.statistics[n.id].authority <= extent[1]
        $scope.nodeFilter.undo('node-authority')
        $scope.nodeFilter.nodesBy(nodeAuthority(extent), 'node-authority').apply()

      hubChangeCallback = (extent) ->
        nodeHub = (extent) ->
          (n) ->
            $scope.statistics[n.id]? and
            $scope.statistics[n.id].hub >= extent[0] and
            $scope.statistics[n.id].hub <= extent[1]
        $scope.nodeFilter.undo('node-hub')
        $scope.nodeFilter.nodesBy(nodeHub(extent), 'node-hub').apply()

      $scope.filters =
        degreeRange: [0, 100]
        degreeChange: degreeChangeCallback
        authorityRange: [0, 100]
        authorityChange: authorityChangeCallback
        hubRange: [0, 100]
        hubChange: hubChangeCallback

      $scope.nodeFilter = sigma.plugins.filter($scope.sigma)

      $scope.controls =
        policyLoaded: false
        tab: 'statisticsTab'
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
        .domain(["subj", "obj.class"])
        .range(["#005892", "#ff7f0e"])

      $scope.update_view = () ->
        width = 4000
        height = 4000

        $scope.policy = IDEBackend.current_policy

        if not $scope.policy?.json?.parameterized?.condensed?
          return

        $scope.controls.policyLoaded = true

        $scope.nodes = $scope.policy.json.parameterized.condensed.nodes
        $scope.links = $scope.policy.json.parameterized.condensed.links

        # Compute degree of each node
        $scope.links.forEach (l) ->
          l.source.degree = if l.source.degree then l.source.degree + 1 else 1
          l.target.degree = if l.target.degree then l.target.degree + 1 else 1

        maxDegree = d3.max($scope.nodes, (n) -> n.degree)

        $scope.filters.classList = []
        $scope.filters.permList = []
        $scope.filters.subjList = []
        $scope.filters.objList = []

        $scope.policy.json.parameterized.condensed.nodes.forEach (n) ->
          if n.name.indexOf('.') == -1
            $scope.filters.subjList.push n.name
          else
            $scope.filters.objList.push n.name.split('.')[0]
            $scope.filters.classList.push n.name.split('.')[1]

        $scope.filters.subjList = _.uniq $scope.filters.subjList
        $scope.filters.objList = _.uniq $scope.filters.objList
        $scope.filters.classList = _.uniq $scope.filters.classList

        $scope.filters.permList = _.uniq(d3.merge($scope.links.map((l) -> l.perm )))

        force = d3.layout.fastForce()
          .gravity(0.05)
          .size([width, height])
          .nodes($scope.nodes)
          .links($scope.links)
          .linkStrength(0.8)
          .linkDistance(40)
          .charge((d) -> return -100 - 200 * d.degree/maxDegree)

        # Compute 50 ticks of the layout
        force.start()
        for i in [0...100]
          force.tick()
        force.stop()

        graph =
          nodes: []
          edges: []

        graph.nodes = $scope.nodes.map (n) ->
          id: n.name
          label: n.name
          x: n.x
          y: n.y
          size: 1
          color: nodeFillScale(n.name.indexOf('.') >= 0 ? 'obj.class' : 'subj')

        graph.edges = $scope.links.map (l) ->
          id: l.source.name + '-' + l.target.name
          source: l.source.name
          target: l.target.name
          size: 1

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

      IDEBackend.add_hook "json_changed", $scope.update_view
      IDEBackend.add_hook "policy_load", IDEBackend.load_condensed_graph
      
      $scope.$on "$destroy", ->
        IDEBackend.unhook "json_changed", $scope.update_view
        IDEBackend.unhook "policy_load", IDEBackend.load_condensed_graph

      $scope.policy = IDEBackend.current_policy

      # Load the raw graph data if it is not loaded
      if $scope.policy?._id and not $scope.policy.json?.parameterized?.condensed?
        IDEBackend.load_condensed_graph()

      # If the graph data is already loaded, render the view
      if $scope.policy?.json?.parameterized?.condensed?
        $scope.update_view()