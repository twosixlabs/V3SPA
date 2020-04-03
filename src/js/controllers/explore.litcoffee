    vespaControllers = angular.module('vespaControllers')

    vespaControllers.controller 'exploreCtrl', ($scope, VespaLogger, WSUtils, $compile,
        IDEBackend, $timeout, $modal, PositionManager, RefPolicy, $q, SockJSService) ->

      # The 'outstanding' attribute is truthy when a policy is being loaded
      $scope.status = SockJSService.status

      nodeFillScale = d3.scale.ordinal()
        .domain(["subj", "obj.class"])
        .range(["#4c84c3", "#ffb048"])

      nodeOverFillScale = d3.scale.ordinal()
        .domain(["subj", "obj.class"])
        .range(["#005892", "#ff7f0e"])

      $scope.sigma = sigma.instances('explore')

      if not $scope.sigma
        $scope.sigma = new sigma(
          id: 'explore'
          renderers: [
            container: 'explore-container'
            type: 'canvas'
          ]
          settings:
            minNodeSize: 2
            maxNodeSize: 2
            minEdgeSize: 0.5
            maxEdgeSize: 0.5
            edgeColor: "default"
            labelThreshold: 8
            singleHover: true
            hideEdgesOnMove: true
            mouseZoomDuration: 0
            doubleClickZoomDuration: 0
            batchEdgesDrawing: true
            canvasEdgesBatchSize: 2000
            defaultNodeType: 'border'
        )

      $scope.sigma.bind 'clickStage rightClickStage', (event) ->
        $scope.clickedNode = null
        $scope.clickedNodeRules = []
        if not $scope.$$phase then $scope.$apply()

        $scope.sigma.graph.nodes().forEach (n) ->
          n.color = nodeFillScale(if n.id.indexOf('.') >= 0 then 'obj.class' else 'subj')
          n.borderColor = '#ffffff'
        $scope.sigma.refresh()

      $scope.sigma.bind 'clickNode', (event) ->
        node = event.data.node
        $scope.clickedNode = node

        neighbors = {}
        $scope.sigma.graph.adjacentNodes(node.id).forEach (neighborNode) ->
          neighbors[neighborNode.id] = node
        neighbors[node.id] = node

        $scope.sigma.graph.nodes().forEach (n) ->
          if neighbors[n.id]
            n.color = nodeOverFillScale(if n.id.indexOf('.') >= 0 then 'obj.class' else 'subj')
            n.borderColor = '#333333'
          else
            n.color = nodeFillScale(if n.id.indexOf('.') >= 0 then 'obj.class' else 'subj')
            n.borderColor = '#ffffff'

        reqParams = {}

        if node.id.indexOf('.') >= 0
          reqParams['object'] = node.id.split('.')[0]
          reqParams['class'] = node.id.split('.')[1]
        else
          reqParams['subject'] = node.id

        req = 
          domain: 'raw'
          request: 'fetch_rules'
          payload:
            policy: [IDEBackend.current_policy._id]
            params: reqParams

        SockJSService.send req, (result)=>
          if result.error?
            $scope.clickedNodeRules = []
          else
            $scope.clickedNodeRules = JSON.parse(result.payload).map((r) -> return r.rule).sort()

        $scope.sigma.refresh()

      tooltipsConfig =
        node:
          show: 'rightClickNode'
          position: 'top'
          template: """
          <condensed-tooltip node="controls.tooltipNode"
                             alternate-nodes="controls.tooltipAlternateNodes"
                             show-neighbors="filters.showNeighbors(node)"
                             add-to-always-visible-list="filters.addToAlwaysVisibleList(nodes)"
                             remove-from-always-visible-list="filters.removeFromAlwaysVisibleList(node)"
                             show-neighbors="filters.showNeighbors(node)"
                             is-always-visible="{{isInAlwaysVisibleList(controls.tooltipNode)}}"
                             sigma="sigma"
                             statistics="statistics"
                             authority-formatter="authorityFormatter"
                             hub-formatter="hubFormatter"
                             >
          </condensed-tooltip>
          """
          renderer: (node, template) ->
            $scope.controls.tooltipNode = node

            if node.id.indexOf('.') == -1
              # The clicked node is a subject, find all objects
              $scope.controls.tooltipAlternateNodes = $scope.sigma.graph.nodes().filter (n) ->
                return n.id != node.id and n.id.indexOf(node.id) >= 0
            else
              # The clicked node is an object.class, find the subject node
              obj = node.id.split('.')[0]
              $scope.controls.tooltipAlternateNodes = $scope.sigma.graph.nodes().filter (n) ->
                return obj == node.id

            $compile(template)($scope)[0]

      $scope.statistics
      $scope.tooltips = sigma.plugins.tooltips($scope.sigma, $scope.sigma.renderers[0], tooltipsConfig)

      $scope.dragListener = sigma.plugins.dragNodes($scope.sigma, $scope.sigma.renderers[0])

      $scope.isInAlwaysVisibleList = (node) ->
        if not node? then return false
        for tag in $scope.controls.alwaysVisible
          if node.id == tag.text then return true
        return false

      addToAlwaysVisibleList = (nodes) ->
        if nodes.constructor != Array then nodes = [nodes]

        nodes.forEach (n) ->
          if not $scope.isInAlwaysVisibleList(n)
            $scope.controls.alwaysVisible.push { text: n.id }

        $scope.nodeFilter.apply()

      removeFromAlwaysVisibleList = (node) ->
        $scope.controls.alwaysVisible = $scope.controls.alwaysVisible.filter (tag) ->
          tag.text != node.id

      clearAlwaysVisibleList = () ->
        $scope.controls.alwaysVisible = []
        $scope.nodeFilter.apply()

      showNeighborsCallback = (node) ->
        selectItem = (type) ->
          (d) -> if d.name == type then d.selected = true

        # Make all the neighbors visible (and other nodes that have the same
        # object or class)
        adjacentNodes = $scope.sigma.graph.adjacentNodes(node.id)

        newTags = adjacentNodes.filter (adjNode) ->
          for tag in $scope.controls.alwaysVisible
            if tag.text == adjNode.id then return false
          return true

        newTags = newTags.map (node) -> return { text: node.id }

        $scope.controls.alwaysVisible = $scope.controls.alwaysVisible.concat(newTags)

        # Get the permissions from all incident edges and make them visible
        adjacentEdges = $scope.sigma.graph.adjacentEdges(node.id)
        edgePerms = _.uniq d3.merge(adjacentEdges.map((e) -> return e.perm))
        $scope.filters.permList.forEach (d) ->
          if edgePerms.indexOf(d.name) then d.selected = true

        # $scope.nodeFilter.apply() is called implicitly here
        avChangeCallback()

      degreeChangeCallback = (extent) ->
        nodeDegree = (n) ->
          ($scope.sigma.graph.degree(n.id) >= extent[0] and
          $scope.sigma.graph.degree(n.id) <= extent[1]) or
          $scope.isInAlwaysVisibleList(n)
        $scope.nodeFilter.undo('node-degree')
        $scope.nodeFilter.nodesBy(nodeDegree, 'node-degree').apply()

      authorityChangeCallback = (extent) ->
        nodeAuthority = (n) ->
          ($scope.statistics[n.id]? and
          $scope.statistics[n.id].authority >= extent[0] and
          $scope.statistics[n.id].authority <= extent[1]) or
          $scope.isInAlwaysVisibleList(n)
        $scope.nodeFilter.undo('node-authority')
        $scope.nodeFilter.nodesBy(nodeAuthority, 'node-authority').apply()

      hubChangeCallback = (extent) ->
        nodeHub = (n) ->
          ($scope.statistics[n.id]? and
          $scope.statistics[n.id].hub >= extent[0] and
          $scope.statistics[n.id].hub <= extent[1]) or
          $scope.isInAlwaysVisibleList(n)
        $scope.nodeFilter.undo('node-hub')
        $scope.nodeFilter.nodesBy(nodeHub, 'node-hub').apply()

      showConnectionsOnlyChangedCallback = () ->
        $scope.applyFilters()
        $scope.sigma.refresh()

      # User checked/unchecked something in the access vector filter
      avChangeCallback = () ->
        checkboxReducer = (map, currItem) ->
          if currItem.selected then map[currItem.name] = true
          return map
        avObjClsMap = d3.merge(
          [
            $scope.filters.objList,
            $scope.filters.classList
          ]).reduce(checkboxReducer, {})
        avSubjMap = $scope.filters.subjList.reduce(checkboxReducer, {})
        avEdgeMap = $scope.filters.permList.reduce(checkboxReducer, {})

        nodeAv = (n) ->
          if n.id.indexOf('.') >= 0 # object.class
            obj = n.id.split('.')[0]
            cls = n.id.split('.')[1]
            return (avObjClsMap[obj] or avObjClsMap[cls]) or $scope.isInAlwaysVisibleList(n)
          else # subject
            return avSubjMap[n.id] or $scope.isInAlwaysVisibleList(n) or false

        edgeAv = (e) ->
          for perm in e.perm
            if avEdgeMap[perm] then return true
          return false

        $scope.nodeFilter.undo('av-node-checkbox')
        $scope.nodeFilter.nodesBy(nodeAv, 'av-node-checkbox').apply()
        $scope.nodeFilter.undo('av-edge-checkbox')
        $scope.nodeFilter.edgesBy(edgeAv, 'av-edge-checkbox').apply()

      denialChangeCallback = () ->
        denial = $scope.filters.denial

        if denial.length == 0
          perm = []
          subj = ''
          obj = ''
          cls = ''

        else
          try 
            # Permission list is between '{' and '}'.
            # Replace all whitespace strings with a single space.
            startIdx = denial.indexOf('{') + 1
            endIdx = denial.indexOf('}')
            if startIdx == 0 or endIdx == -1
              throw new Error('Error parsing permissions in AVC denial: Could not find { or }')
            perm = denial.slice(startIdx, endIdx).trim().replace(/\s\s+/g, ' ')
            perm = perm.split(' ')

            # Might throw index out of bounds if could not find the class
            try
              cls = denial.match(/tclass=\S+/)[0]
              cls = cls.replace('tclass=', '')
            catch e
              errorMsg = 'Error parsing the target class in AVC denial:
              Could not find "tclass=example_class_name"'
              throw new Error(errorMsg)

            try
              # Of the form "scontext=u:role:type:sensitivity"
              scontext = denial.match(/scontext=\S+/)[0]
              scontext = scontext.split(':')
              subj = scontext[2]
            catch e
              errorMsg = 'Error parsing source context in AVC denial:
              Could not find "tcontext=example_u:example_r:example_t"'
              throw new Error(errorMsg)

            try
              # Of the form "tcontext=u:role:type:sensitivity"
              tcontext = denial.match(/tcontext=\S+/)[0]
              tcontext = tcontext.split(':')
              obj = tcontext[2]
            catch e
              errorMsg = 'Error parsing target context in AVC denial:
              Could not find "tcontext=example_u:example_r:example_t"'
              throw new Error(errorMsg)

          catch e
            VespaLogger.log 'policy', 'error', e.message
            perm = []
            subj = ''
            obj = ''
            cls = ''
        
        # Select/unselect the appropriate AV elements

        subjObjClsIter = (type) ->
          (d) ->
            if !type or type == d.name
              d.selected = true
            else
              d.selected = false

        $scope.filters.subjList.forEach subjObjClsIter(subj)
        $scope.filters.objList.forEach subjObjClsIter(obj)
        $scope.filters.classList.forEach subjObjClsIter(cls)

        $scope.filters.permList.forEach (d) ->
          if perm.length == 0 or perm.indexOf(d.name) >= 0
            d.selected = true
          else
            d.selected = false

        avChangeCallback()


      denialClearCallback = () ->
        $scope.filters.denial = ''
        denialChangeCallback()

      getAutocompleteItems = (query) ->
        filtered = $scope.sigma.graph.nodes().filter (n) -> n.id.includes(query)
        filtered = filtered.map (n) -> { text: n.id }
        filtered.sort (a, b) -> if a.text < b.text then -1 else if a.text > b.text then 1 else 0

      $scope.filters =
        degreeRange: [0, 100]
        degreeChange: degreeChangeCallback
        authorityRange: [0, 100]
        authorityChange: authorityChangeCallback
        hubRange: [0, 100]
        hubChange: hubChangeCallback
        avChange: avChangeCallback
        dential: ""
        denialChange: denialChangeCallback
        denialClear: denialClearCallback
        showNeighbors: showNeighborsCallback
        addToAlwaysVisibleList: addToAlwaysVisibleList
        removeFromAlwaysVisibleList: removeFromAlwaysVisibleList
        clearAlwaysVisibleList: clearAlwaysVisibleList
        showConnectionsOnlyChanged: showConnectionsOnlyChangedCallback

      $scope.applyFilters = () ->
        $scope.nodeFilter.apply()

        # Filter for nodes with no visible connections after all other filters
        # are applied.
        if $scope.controls.connectionsOnly
          g = $scope.sigma.graph
          g.nodes().forEach((n) ->
            n.hidden = n.hidden || _.every(g.adjacentEdges(n.id), (e) -> e.hidden)
          )

      $scope.nodeFilter = new sigma.plugins.filter($scope.sigma)

      zoomInCallback = () ->
        camera = $scope.sigma.camera
        camera.goTo({ratio: camera.ratio / camera.settings('zoomingRatio')})

      zoomOutCallback = () ->
        camera = $scope.sigma.camera
        camera.goTo({ratio: camera.ratio * camera.settings('zoomingRatio')})

      $scope.controls =
        zoomIn: zoomInCallback
        zoomOut: zoomOutCallback
        showModuleSelect: false
        alwaysVisible: []
        autocompleteItems: getAutocompleteItems
        tooltipNode: null
        policyLoaded: false
        tab: 'statisticsTab'
        linksVisible: false
        links:
          primary: true
          both: true
          comparison: true
        connectionsOnly: false

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

      $scope.update_view = () ->
        width = 6000
        height = 6000

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

        # Get the lists of subjects, objects, classes, and permissions
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

        $scope.filters.subjList = _.uniq($scope.filters.subjList).sort()
        $scope.filters.objList = _.uniq($scope.filters.objList).sort()
        $scope.filters.classList = _.uniq($scope.filters.classList).sort()
        $scope.filters.permList = _.uniq(d3.merge($scope.links.map((l) -> l.perm ))).sort()

        itemMap = (item) ->
          name: item
          selected: true

        $scope.filters.subjList = $scope.filters.subjList.map itemMap
        $scope.filters.objList = $scope.filters.objList.map itemMap
        $scope.filters.classList = $scope.filters.classList.map itemMap
        $scope.filters.permList = $scope.filters.permList.map itemMap

        force = d3.layout.fastForce()
          .gravity(0.04)
          .size([width, height])
          .nodes($scope.nodes)
          .links($scope.links)
          .linkStrength((d) -> return 1 - Math.max(d.source.degree, d.target.degree) / (2*maxDegree))
          .linkDistance((d) -> return 100 + 500 * Math.max(d.source.degree, d.target.degree) / maxDegree)
          .charge((d) -> return -20 - 20 * d.degree/maxDegree)
          #.linkDistance((d) -> return 1000 + 8000 / (d.perm.length*10))

        # Compute several ticks of the layout, but only if they don't have a position
        if not ($scope.nodes?[0]?.hasOwnProperty('x') and $scope.nodes?[0]?.hasOwnProperty('y'))
          force.start()
          for i in [0...70]
            force.tick()

            for node in $scope.nodes
              if node.x > width then node.x = width else if node.x < 0 then node.x = 0
              if node.y > height then node.y = height else if node.y < 0 then node.y = 0
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
          color: nodeFillScale(if n.name.indexOf('.') >= 0 then 'obj.class' else 'subj')

        graph.edges = $scope.links.map (l) ->
          id: l.source.name + '-' + l.target.name
          source: l.source.name
          target: l.target.name
          size: 1
          perm: l.perm
          color: "rgba(85,85,85,0.5)"

        $scope.sigma.graph.clear()
        $scope.sigma.graph.read(graph)
        $scope.statistics = $scope.sigma.graph.HITS()
        $scope.filters.degreeRange = d3.extent(graph.nodes, (n) -> $scope.sigma.graph.degree(n.id))
        $scope.filters.authorityRange = d3.extent(d3.values($scope.statistics), (n) -> n.authority)
        $scope.filters.hubRange = d3.extent(d3.values($scope.statistics), (n) -> n.hub)

        $scope.authorityFormatter = d3.scale.linear()
          .domain($scope.filters.authorityRange)
          .tickFormat()
        $scope.hubFormatter = d3.scale.linear()
          .domain($scope.filters.hubRange)
          .tickFormat()
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
        sigma.plugins.killDragNodes($scope.sigma)
        $scope.sigma.kill()

      $scope.policy = IDEBackend.current_policy

      # Load the raw graph data if it is not loaded
      if $scope.policy?._id and not $scope.policy.json?.parameterized?.condensed?
        IDEBackend.load_condensed_graph()

      # If the graph data is already loaded, render the view
      if $scope.policy?.json?.parameterized?.condensed?
        $scope.update_view()
