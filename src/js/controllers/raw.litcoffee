    vespaControllers = angular.module('vespaControllers')

    vespaControllers.controller 'rawCtrl', ($scope, VespaLogger,
        IDEBackend, $timeout, $modal, PositionManager, $q, SockJSService) ->

      barHeight = 20
      barWidth = 300
      duration = 400
      root = {}
      svg = d3.select("svg.rawview").select("g.viewer")
      tree = d3.layout.tree()
        .nodeSize([0, 20])

      $scope.update_view = (data) ->
        $scope.policy = IDEBackend.current_policy

        # If the policy has changed, need to update/remove the old visuals
        $scope.rules = if data.parameterized?.rules? then data.parameterized.rules else []

        rules_root = {}

        # Group the rules by directory and module
        rules_root = _.reduce($scope.rules, (root, d) ->
          d.name = d.subject
          directory = _.findWhere(root.children, {directory: d.directory})
          if directory
            module = _.findWhere(directory.children, {module: d.module})
            if module
              #module.children.push d
            else
              directory.children.push {name:d.module, module: d.module}
          else
            root.children.push {name: d.directory, directory: d.directory, children: [{name: d.module, module: d.module}]}
          return root
        , {name: (if $scope.policy?.id? then $scope.policy.id else ""), children: []})

        rules_root.x0 = 0
        rules_root.y0 = 0

        console.log "New policy #{$scope.policy.id}"

        update(root = rules_root)

      update = (rules_root) ->
        nodes = tree.nodes(root)
        _.each nodes, (d,i) ->
          d.x = i * barHeight

        height = 500

        d3.select("svg.rawview").transition()
          .duration(duration)
          .attr("height", height)

        node = svg.selectAll("g.node")
          .data(nodes, (d,i) -> return d.id or (d.id = $scope.policy.id + "-" + i))

        nodeEnter = node.enter().append("g")
          .attr("class", "node")
          .attr("transform", (d) -> return "translate(#{rules_root.y0},#{rules_root.x0})")
          .style("opacity", 1e-6)

        nodeEnter.append("rect")
          .attr("y", -barHeight/2)
          .attr("height", barHeight)
          .attr("width", barWidth)
          .style("fill", color)
          .on("click", click)

        nodeEnter.append("text")
          .attr("dy", 3.5)
          .attr("dx", 5.5)
          .text((d) -> if d.children? then "#{d.name} (#{d.children.length})" else if d._children? then "#{d.name} (#{d._children.length})" else d.name)

        nodeEnter.transition()
          .duration(duration)
          .attr("transform", (d) -> "translate(#{d.y},#{d.x})")
          .style("opacity", 1)

        node.transition()
          .duration(duration)
          .attr("transform", (d) -> "translate(#{d.y},#{d.x})")
          .style("opacity", 1)
          .select("rect")
          .style("fill", color)

        node.exit().transition()
          .duration(duration)
          .attr("transform", (d) -> "translate(#{rules_root.y},#{rules_root.x})")
          .style("opacity", 1e-6)
          .remove()

        _.each nodes, (d) ->
          d.x0 = d.x
          d.y0 = d.y

      click = (d) ->
        if d.children
          d._children = d.children
          d.children = null
        else
          d.children = d._children
          d._children = null
        update(d)

      color = (d) ->
        if d._children
          return '#3182bd'
        else if d.children
          return '#c6dbef'
        else
          return '#fd8d3c'

Set up the viewport scroll

      positionMgr = PositionManager("tl.viewport::#{IDEBackend.current_policy._id}",
        {a: 0.7454701662063599, b: 0, c: 0, d: 0.7454701662063599, e: 200, f: 50}
      )

      svgPanZoom.init
        selector: '#surface svg'
        panEnabled: true
        zoomEnabled: true
        dragEnabled: false
        minZoom: 0.5
        maxZoom: 10
        onZoom: (scale, transform) ->
          positionMgr.update transform
        onPanComplete: (coords, transform) ->
          positionMgr.update transform

      $scope.$watch(
        () -> return (positionMgr.data)
        , 
        (newv, oldv) ->
          if not newv? or _.keys(newv).length == 0
            return
          g = svgPanZoom.getSVGViewport($("#surface svg")[0])
          svgPanZoom.set_transform(g, newv)
      )

      IDEBackend.add_hook "json_changed", $scope.update_view
      $scope.$on "$destroy", ->
        IDEBackend.unhook "json_changed", $scope.update_view

      start_data = IDEBackend.get_json()
      if start_data
        $scope.update_view(start_data)