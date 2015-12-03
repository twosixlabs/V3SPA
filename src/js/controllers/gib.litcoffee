    vespaControllers = angular.module('vespaControllers')

    vespaControllers.controller 'gibCtrl', ($scope, VespaLogger,
        IDEBackend, $timeout, $modal, PositionManager, RefPolicy, $q, SockJSService) ->

      comparisonPolicy = null
      $scope.input = 
        refpolicy: comparisonPolicy

      # The 'outstanding' attribute is truthy when a policy is being loaded
      $scope.status = SockJSService.status

      fetch_raw = ->
        deferred = $q.defer()

        path_params = IDEBackend.write_filter_param([])

        req =
          domain: 'raw'
          request: 'parse'
          payload:
            policy: comparisonPolicy._id
            text: comparisonPolicy.documents.raw.text
            params: path_params.join("&")

        SockJSService.send req, (result)=>
          if result.error  # Service error

            $.growl(
              title: "Error"
              message: result.payload
            ,
              type: 'danger'
            )

            deferred.reject result.payload

          else  # valid response. Must parse
            comparisonPolicy.json = JSON.parse result.payload

            deferred.resolve()

        return deferred.promise

      load_refpolicy = (id)=>
        if comparisonPolicy? and comparisonPolicy.id == id
          return

        deferred = @_deferred_load || $q.defer()

        req = 
          domain: 'refpolicy'
          request: 'get'
          payload: id

        SockJSService.send req, (data)=>
          if data.error?
            comparisonPolicy = null
            deferred.reject(comparisonPolicy)
          else
            comparisonPolicy = data.payload
            comparisonPolicy._id = comparisonPolicy._id.$oid

            console.log 'policy', 'info', "Loaded Reference Policy: #{comparisonPolicy.id}"

            deferred.resolve(comparisonPolicy)

        return deferred.promise

      $scope.load = ->
        load_refpolicy($scope.input.refpolicy.id).then(fetch_raw)

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

      width = 250
      height = 500
      graph =
        links: []
        subjNodes: []
        objNodes: []
        classNodes: []
      color = d3.scale.category10()
      svg = d3.select("svg.gibview").select("g.viewer")
      subjSvg = svg.select("g.subjects").attr("transform", "translate(0,0)")
      objSvg = svg.select("g.objects").attr("transform", "translate(#{width},0)")
      classSvg = svg.select("g.classes").attr("transform", "translate(#{2*width},0)")
      subjForce = d3.layout.force().size([width, height]).charge(-40)
      objForce = d3.layout.force().size([width, height]).charge(-40)
      classForce = d3.layout.force().size([width, height]).charge(-40)

      textStyle =
        'text-anchor': "middle"
        'fill': "#ddd"
        'font-size': "56px"
      svg.select("g.labels").append("text")
        .attr "x", width / 2
        .attr "y", height / 2
        .style textStyle
        .text "subjects"
      svg.select("g.labels").append("text")
        .attr "x", width + width / 2
        .attr "y", height / 2
        .style textStyle
        .text "objects"
      svg.select("g.labels").append("text")
        .attr "x", 2 * width + width / 2
        .attr "y", height / 2
        .style textStyle
        .text "classes"

      $scope.update_view = (data) ->
        $scope.policy = IDEBackend.current_policy

        # If the policy has changed, need to update/remove the old visuals
        $scope.rules = if data.parameterized?.rules? then data.parameterized.rules else []

        nodes = []
        graph.links.length = 0

        # Get a list of unique subjects, objects, and classes
        # Get a list of links (subject -> object, and object -> class)
        # For each link, store an array of rules from which the link was derived
        $scope.rules.forEach (r) ->
          new_subject_node = new_object_node = new_class_node = undefined

          curr_subject_node = _.findWhere(nodes, {type: "subject", name: r.subject})
          curr_object_node = _.findWhere(nodes, {type: "object", name: r.object})
          curr_class_node = _.findWhere(nodes, {type: "class", name: r.class})

          unless curr_subject_node
            new_subject_node = {type: "subject", name: r.subject, rule: r}
            nodes.push new_subject_node
          unless curr_object_node
            new_object_node = {type: "object", name: r.object, rule: r}
            nodes.push new_object_node
          unless curr_class_node
            new_class_node = {type: "class", name: r.class, rule: r}
            nodes.push new_class_node

          # Create the subject->object links
          if curr_subject_node and !curr_object_node
            graph.links.push {source: curr_subject_node, target: new_object_node, rules: [new_object_node.rule]}
          else if !curr_subject_node and curr_object_node
            graph.links.push {source: new_subject_node, target: curr_object_node, rules: [new_subject_node.rule]}
          else if !curr_subject_node and !curr_object_node
            graph.links.push {source: new_subject_node, target: new_object_node, rules: [new_subject_node.rule]}
          else
            l = _.findWhere graph.links, {source: curr_subject_node, target: curr_object_node}
            if l
              l.rules.push r
            else
              # Subject and object were previously found in two separate rules
              graph.links.push {source: curr_subject_node, target: curr_object_node, rules: [r]}

          # Create the object->class links
          if curr_object_node and !curr_class_node
            graph.links.push {source: curr_object_node, target: new_class_node, rules: [new_class_node.rule]}
          else if !curr_object_node and curr_class_node
            graph.links.push {source: new_object_node, target: curr_class_node, rules: [new_object_node.rule]}
          else if !curr_object_node and !curr_class_node
            graph.links.push {source: new_object_node, target: new_class_node, rules: [new_object_node.rule]}
          else
            l = _.findWhere graph.links, {source: curr_object_node, target: curr_class_node}
            if l
              l.rules.push r
            else
              # Object and class were previously found in two separate rules
              graph.links.push {source: curr_object_node, target: curr_class_node, rules: [r]}

        graph.subjNodes = nodes.filter (d) -> d.type == "subject"
        graph.objNodes = nodes.filter (d) -> d.type == "object"
        graph.classNodes = nodes.filter (d) -> d.type == "class"

        update()

      update = () ->
        subjForce.nodes(graph.subjNodes).start()
        objForce.nodes(graph.objNodes).start()
        classForce.nodes(graph.classNodes).start()

        link = svg.select("g.links").selectAll ".link"
          .data graph.links, (d,i) -> return d.id or (d.id = $scope.policy.id + "-" + i)

        link.enter().append "line"
          .attr "class", (d) -> "link l-#{d.source.type}-#{d.source.name}-#{d.target.type}-#{d.target.name}"
          .style "stroke-width", (d) -> return d.rules.length
          .style "display", "none"

        link.style "stroke-width", (d) -> return d.rules.length

        link.exit().remove()

        [
          {force: subjForce, nodes: graph.subjNodes, svg: subjSvg},
          {force: objForce, nodes: graph.objNodes, svg: objSvg},
          {force: classForce, nodes: graph.classNodes, svg: classSvg}
        ].forEach (tuple) ->
          nodeMouseover = (d,i) ->
            linksToShow = []

            # Find all links associated with this node
            if d.type == "object"
              linksToShow = _.where graph.links, {target: d}
              linksToShow = linksToShow.concat _.where graph.links, {source: d}
            else if d.type == "subject"
              linksToShow = _.where graph.links, {source: d}
              linksToShow = linksToShow.concat _.filter graph.links, (link) -> return _.findWhere linksToShow, {target: link.source}
            else # this is d.type == "class"
              linksToShow = _.where graph.links, {target: d}
              linksToShow = linksToShow.concat _.filter graph.links, (link) -> return _.findWhere linksToShow, {source: link.target}

            d3.selectAll linksToShow.map((link) -> ".l-#{link.source.type}-#{link.source.name}-#{link.target.type}-#{link.target.name}").join ","
              .style "display", ""

            uniqNodes = linksToShow.reduce((prev, l) ->
              prev.push l.source
              prev.push l.target
              return prev
            , [])
            
            d3.selectAll _.uniq(uniqNodes.map((n) -> return "text.t-#{n.type}-#{n.name}")).join(",")
              .style "display", ""
            d3.selectAll _.uniq(uniqNodes.map((n) -> return "g.node.t-#{n.type}-#{n.name}")).join(",")
              .each () -> @.parentNode.appendChild(@)

          nodeMouseout = (d,i) ->
            link.style "display", "none"
            d3.selectAll "g.node text"
              .style "display", "none"

          node = tuple.svg.selectAll ".node"
            .data tuple.nodes, (d,i) -> return d.id or (d.id = $scope.policy.id + "-" + i)

          nodeEnter = node.enter().append "g"
            .attr "class", (d) -> "node t-#{d.type}-#{d.name}"

          nodeEnter.append "text"
            .attr "class", (d) -> "node-label t-#{d.type}-#{d.name}"
            .attr "x", 0
            .attr "y", "-5px"
            .style "display", "none"
            .text (d) -> d.name

          nodeEnter.append "circle"
            .attr "r", 5
            .attr "cx", 0
            .attr "cy", 0
            .style "fill", (d) -> return "url(#diff-left)"
            .on "mouseover", nodeMouseover
            .on "mouseout", nodeMouseout

          node.exit().remove()

          tuple.force.on "tick", (e) ->
            link.attr "x1", (d) -> return d.source.x + if d.source.type == "object" then width else 0
              .attr "y1", (d) -> return d.source.y
              .attr "x2", (d) -> return d.target.x + if d.target.type == "object" then width else 2*width
              .attr "y2", (d) -> return d.target.y

            node.attr "transform", (d) -> return "translate(#{d.x},#{d.y})"

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