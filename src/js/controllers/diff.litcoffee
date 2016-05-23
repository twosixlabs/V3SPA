    vespaControllers = angular.module('vespaControllers')

    vespaControllers.controller 'diffCtrl', ($scope, VespaLogger,
        IDEBackend, $timeout, $modal, PositionManager, RefPolicy, $q, SockJSService) ->

      comparisonPolicy = null
      comparisonRules = []
      $scope.input = 
        refpolicy: comparisonPolicy
      $scope.modules = []

      # The 'outstanding' attribute is truthy when a policy is being loaded
      $scope.status = SockJSService.status

      $scope.controls =
        allModulesChecked: true
        tab: 'nodesTab'
        linksVisible: false
        links:
          primary: true
          both: true
          comparison: true

      $scope.$watch 'controls.links', ((value) -> if value then redraw()), true
      $scope.$watch 'controls.linksVisible', ((value) -> if value == false or value == true then redraw())

      comparisonPolicyId = () ->
        if comparisonPolicy then comparisonPolicy.id else ""

      primaryPolicyId = () ->
        if IDEBackend.current_policy then IDEBackend.current_policy.id else ""

Get the raw JSON

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
            comparisonRules = comparisonPolicy.json.parameterized.rules

            deferred.resolve()

        return deferred.promise

Fetch the policy info (refpolicy) needed to get the raw JSON

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

            deferred.resolve(comparisonPolicy)

        return deferred.promise
      
Enumerate the differences between the two policies

      find_differences = () =>
        graph.links.length = 0

        primaryNodes = []
        primaryNodeMap = $scope.nodeMap
        comparisonNodes = []
        primaryLinkMap = $scope.linkMap

        comparisonNodeMap = if comparisonPolicy?.json?.parameterized?.nodemap?
          comparisonNodeMap = data.parameterized.nodemap
        else
          comparisonNodeMap = {}

        comparisonLinkMap = if comparisonPolicy?.json?.parameterized?.linkmap?
          comparisonLinkMap = data.parameterized.nodemap
        else
          comparisonLinkMap = {}

        console.log "ROAR"

        # Reconcile the two lists of links
        # Loop over the primary links: if in comparison links
        # - change "policy" to "both"
        # - set it to unselected
        # - push the comparison's rules onto the primary's (ignore duplicates)
        # - remove from comparisonNodes
        primaryLinks = d3.values primaryLinkMap
        console.log "primaryLinks", primaryLinks.length
        primaryLinks.forEach (link) ->
          comparisonLink = comparisonLinkMap["#{link.source.type}-#{link.source.name}-#{link.target.type}-#{link.target.name}"]
          if comparisonLink
            link.rules = _.uniq link.rules.concat(comparisonLink.rules)
            link.policy = "both"
            delete comparisonLinkMap["#{link.source.type}-#{link.source.name}-#{link.target.type}-#{link.target.name}"]

        graph.links = d3.values(comparisonLinkMap).concat(primaryLinks)

        # Reconcile the two lists of nodes
        # Loop over the primary nodes: if in comparison nodes
        # - change "policy" to "both"
        # - set it to unselected
        # - push the comparison's rules onto the primary's (ignore duplicates)
        # - remove from comparisonNodes
        primaryNodes = d3.values primaryNodeMap
        primaryNodes.forEach (node) ->
          comparisonNode = comparisonNodeMap["#{node.type}-#{node.name}"]
          if comparisonNode
            node.rules = _.uniq node.rules.concat(comparisonNode.rules)
            node.policy = "both"
            node.selected = false
            delete comparisonNodeMap["#{node.type}-#{node.name}"]

            # Rewire the links to use the "both" node instead of comparisonNode
            graph.links.forEach (l) ->
              if l.source == comparisonNode
                l.source = node
              if l.target == comparisonNode
                l.target = node

        # Get a list of modules from the two sets of rules
        $scope.modules = d3.entries(d3.merge([$scope.rules, comparisonRules]).reduce(((modules, rule) ->
          if modules[rule.module] and modules[rule.module] != rule.policy
            modules[rule.module] = "both"
          else
            modules[rule.module] = rule.policy
          return modules
          ), {})).map((module) -> return {module: module.key, policy: module.value, selected: true, indeterminate: false})

        comparisonNodes = d3.values comparisonNodeMap

        # Remove any duplicate links we may have generated by rewiring the links
        graph.links = _.uniq(graph.links, (l) -> return "#{l.source.policy}-#{l.source.type}-#{l.source.name}-#{l.target.policy}-#{l.target.type}-#{l.target.name}")

        graph.allNodes = primaryNodes.concat comparisonNodes

        graph.subjNodes = []
        graph.objNodes = []
        graph.classNodes = []
        graph.permNodes = []

        graph.allNodes.forEach (n) ->
          if n.type == "subject"
            graph.subjNodes.push n
          else if n.type == "object"
            graph.objNodes.push n
          else if n.type == "class"
            graph.classNodes.push n
          else #perm
            graph.permNodes.push n

        linkScale.domain d3.extent(graph.links, (l) -> return l.rules.length)

      $scope.moduleClick = (module) ->
        checkedModules = $scope.modules.filter((mod) -> return mod.selected).map((mod) -> return mod.module)
        # Set node.selected = false if any modules for that node are unselected
        graph.allNodes.forEach (n) ->
          selectedRules = n.rules.filter((r) -> return checkedModules.indexOf(r.module) >= 0)
          if selectedRules.length
            n.selected = true
          else
            n.selected = false
        redraw()

      # Called from the select all/none checkbox
      $scope.selectModulesClick = (val) ->
        $scope.controls.allModulesChecked = val
        $scope.modules.forEach (mod) ->
          mod.selected = val
          mod.indeterminate = false
        graph.allNodes.forEach (n) ->
          n.selected = val
        redraw()
        
      $scope.selectionChange = () ->
        # A node has been checked/unchecked, so update which modules are checked
        checked = {}
        unchecked = {}
        $scope.modules.forEach (m) ->
          checked[m.module] = 0
          unchecked[m.module] = 0
        graph.allNodes.forEach (n) ->
          status = n.selected
          n.rules.forEach (r) ->
            if status
              checked[r.module]++
            else
              unchecked[r.module]++
        $scope.modules.forEach (m) ->
          if checked[m.module] > 0 and unchecked[m.module] > 0
            m.indeterminate = true
            m.selected = true
          else if unchecked[m.module] > 0 # all unchecked
            m.indeterminate = false
            m.selected = false
          else # checked[module] > 0
            m.indeterminate = false
            m.selected = true

        redraw()

      $scope.load = ->
        load_refpolicy($scope.input.refpolicy.id).then(fetch_raw).then(update)

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
      padding = 50
      radius = 5
      graph =
        links: []
        subjNodes: []
        objNodes: []
        classNodes: []
        permNodes: []
        allNodes: []
      $scope.graph = graph
      color = d3.scale.category10()
      svg = d3.select("svg.diffview").select("g.viewer")
      subjSvg = svg.select("g.subjects").attr("transform", "translate(0,0)")
      permSvg = svg.select("g.permissions").attr("transform", "translate(#{width+padding},0)")
      objSvg = svg.select("g.objects").attr("transform", "translate(#{2*(width+padding)},-#{height/2})")
      classSvg = svg.select("g.classes").attr("transform", "translate(#{3*(width+padding)},0)")

      subjSvg.append("rect")
        .attr("width", width + 16)
        .attr("height", height + 16)
        .attr("x", -8)
        .attr("y", -8)
        .attr("style", "fill:rgba(200,200,200,0.15)")
      objSvg.append("rect")
        .attr("width", width + 16)
        .attr("height", height + 16)
        .attr("x", -8)
        .attr("y", -8)
        .attr("style", "fill:rgba(200,200,200,0.15)")
      classSvg.append("rect")
        .attr("width", width + 16)
        .attr("height", height + 16)
        .attr("x", -8)
        .attr("y", -8)
        .attr("style", "fill:rgba(200,200,200,0.15)")
      permSvg.append("rect")
        .attr("width", width + 16)
        .attr("height", height + 16)
        .attr("x", -8)
        .attr("y", -8)
        .attr("style", "fill:rgba(200,200,200,0.15)")

      linkScale = d3.scale.linear()
        .range([1,2*radius])

      gridLayout = d3.layout.grid()
        .points()
        .size([width, height])

      textStyle =
        'text-anchor': "middle"
        'fill': "#ccc"
        'font-size': "56px"
      svg.select("g.labels").append("text")
        .attr "x", width / 2
        .attr "y", height / 2
        .style textStyle
        .text "subjects"
      svg.select("g.labels").append("text")
        .attr "x", (width + padding) + width / 2
        .attr "y", height / 2
        .style textStyle
        .text "permissions"
      svg.select("g.labels").append("text")
        .attr "x", 2 * (width + padding) + width / 2
        .attr "y", 0
        .style textStyle
        .text "objects"
      svg.select("g.labels").append("text")
        .attr "x", 3 * (width + padding) + width / 2
        .attr "y", height / 2
        .style textStyle
        .text "classes"

      nodeExpand = (show, type, clickedNodeData) ->
        nodeArr = graph.subjNodes
        if type == 'perm'
          nodeArr = graph.permNodes
        else if type == 'object'
          nodeArr = graph.objNodes
        else if type == 'class'
          nodeArr = graph.classNodes

        nodeArr.forEach (n) ->
          r = -1
          while ++r < n.rules.length
            if n.rules[r][clickedNodeData.type] == clickedNodeData.name
              n.selected = show
              break

      $scope.update_view = (data) ->
        $scope.policy = IDEBackend.current_policy

        # If the policy has changed, need to update/remove the old visuals
        $scope.rules = if data.parameterized?.rules? then data.parameterized.rules else []
        $scope.nodeMap = if data.parameterized?.nodemap? then data.parameterized.nodemap else []
        $scope.linkMap = if data.parameterized?.linkmap? then data.parameterized.linkmap else []

        update()

      update = () ->
        find_differences()
        $scope.clickedNode = null
        $scope.controls.allModulesChecked = true
        $scope.policyIds =
          primary: primaryPolicyId()
          both: if comparisonPolicyId() then "both" else undefined
          comparison: comparisonPolicyId() || undefined

        if $scope.policyIds.primary and $scope.policyIds.comparison
          redraw()

      redraw = () ->
        [
          {nodes: graph.subjNodes, svg: subjSvg},
          {nodes: graph.objNodes, svg: objSvg},
          {nodes: graph.permNodes, svg: permSvg},
          {nodes: graph.classNodes, svg: classSvg}
        ].forEach (tuple) ->
          getConnected = (d) ->
            linksToShow = []

            # Find all links associated with this node
            if d.type == "object"
              # Get links to permissions
              linksToShow = _.where graph.links, {target: d}
              # Get links to classes
              linksToShow = linksToShow.concat _.where graph.links, {source: d}
              # Get links from permissions to classes, if they are associated with this object
              linksToShow = linksToShow.concat _.filter graph.links, (link) ->
                return _.findWhere(linksToShow, {source: link.source}) and _.findWhere(linksToShow, {target: link.target})
              # Get links from subjects to permissions
              permRules = _.uniq(_.where($scope.rules.concat(comparisonRules), {object: d.name}), (d) -> return d.perm)
              linksToShow = linksToShow.concat _.filter graph.links, (link) -> return _.findWhere permRules, {perm: link.target.name}
            else if d.type == "subject"
              # Get links from permissions to objects and permissions to classes
              permRules = _.uniq(_.where($scope.rules.concat(comparisonRules), {subject: d.name}), (d) -> return d.perm)
              linksToShow = linksToShow.concat _.filter graph.links, (link) -> return _.findWhere permRules, {perm: link.source.name}
              # Get links from objects to classes
              linksToShow = linksToShow.concat _.filter graph.links, (link) ->
                return _.findWhere(linksToShow, {target: link.source}) and _.findWhere(linksToShow, {target: link.target})
              # Get links to permissions
              linksToShow = linksToShow.concat _.where graph.links, {source: d}
            else if d.type == "perm"
              # Get links to objects and classes
              linksToShow = _.where graph.links, {source: d}
              # Get links from objects to classes, if the they are associated with this permission
              linksToShow = linksToShow.concat _.filter graph.links, (link) ->
                return _.findWhere(linksToShow, {target: link.source}) and _.findWhere(linksToShow, {target: link.target})
              # Get links from subjects to this perm
              linksToShow = linksToShow.concat _.where graph.links, {target: d}
            else # this is d.type == "class"
              # Find all permissions and object types on this class
              linksToShow = _.where(graph.links, {target: d})
              # Get links from permissions to objects, if the they are associated with this class
              linksToShow = linksToShow.concat _.filter graph.links, (link) ->
                return _.findWhere(linksToShow, {source: link.source}) and _.findWhere(linksToShow, {source: link.target})
              # Find all subjects that have permissions on this class
              permRules = _.uniq(_.where($scope.rules.concat(comparisonRules), {class: d.name}), (d) -> return d.perm)
              linksToShow = linksToShow.concat _.filter graph.links, (link) -> return _.findWhere permRules, {perm: link.target.name}

            linksToShow = linksToShow.filter (l) -> return l.source.selected && l.target.selected

            uniqNodes = linksToShow.reduce((prev, l) ->
              prev.push l.source
              prev.push l.target
              return prev
            , [])

            # No links to show, so make sure we highlight the node the user moused over
            if uniqNodes.length == 0
              uniqNodes.push d

            uniqNodes = _.uniq uniqNodes

            return [uniqNodes, linksToShow]

          nodeMouseover = (d) ->
            [uniqNodes, linksToShow] = getConnected(d)

            d3.selectAll uniqNodes.map((n) -> return "g.node." + CSS.escape("t-#{n.type}-#{n.name}")).join(",")
              .classed "highlight", true
              .each () -> @.parentNode.appendChild(@)

            # No links to show, so return
            if linksToShow.length == 0
              return

            d3.selectAll linksToShow.map((link) -> "." + CSS.escape("l-#{link.source.type}-#{link.source.name}-#{link.target.type}-#{link.target.name}")).join ","
              .classed "highlight", true
              .each () -> @.parentNode.appendChild(@)

          nodeMouseout = (d) ->
            link.classed "highlight", false
            d3.selectAll "g.node.highlight"
              .classed "highlight", false

          nodeClick = (clickedNode) ->
            [uniqNodes, linksToShow] = getConnected(clickedNode)
            clicked = !clickedNode.clicked

            if clicked
              $scope.clickedNode = clickedNode
            else
              $scope.clickedNode = null
            if !$scope.$$phase then $scope.$apply()

            changedNodes = graph.allNodes.filter (n) -> return n.clicked
            changedLinks = graph.links.filter (l) -> return l.source.clicked && l.target.clicked
            changedLinks = changedLinks.concat linksToShow

            # Set clicked = false on all nodes
            graph.subjNodes.forEach (d) -> d.clicked = false
            graph.objNodes.forEach (d) -> d.clicked = false
            graph.classNodes.forEach (d) -> d.clicked = false
            graph.permNodes.forEach (d) -> d.clicked = false

            # Toggle clicked
            uniqNodes.forEach (d) -> d.clicked = clicked

            changedNodes = changedNodes.concat uniqNodes

            # For all nodes with clicked == true, add the "clicked" class
            d3.selectAll _.uniq(changedNodes.map((n) -> return "g.node." + CSS.escape("t-#{n.type}-#{n.name}"))).join(",")
              .classed "clicked", (d) -> d.clicked
              .each () -> @.parentNode.appendChild(@)

            # No links to show, so return
            if changedLinks.length == 0
              return

            d3.selectAll changedLinks.map((link) -> "." + CSS.escape("l-#{link.source.type}-#{link.source.name}-#{link.target.type}-#{link.target.name}")).join ","
              .classed "clicked", (d) -> d.source.clicked && d.target.clicked

          # Sort first by policy, then by name
          tuple.nodes.sort (a,b) ->
            if (a.policy == primaryPolicyId() && a.policy != b.policy) || (a.policy == "both" && b.policy == comparisonPolicyId())
              return -1
            else if a.policy == b.policy
              return if a.name == b.name then 0 else if a.name < b.name then return -1 else return 1
            else
              return 1

          node = tuple.svg.selectAll ".node"
          
          # Clear the old nodes and redraw everything
          node.remove()

          node = tuple.svg.selectAll ".node"
            .data gridLayout(tuple.nodes.filter (d) -> return d.selected)
            .attr "class", (d) -> "node t-#{d.type}-#{d.name}"
            .classed "clicked", (d) -> d.clicked

          nodeEnter = node.enter().append "g"
            .attr "class", (d) -> "node t-#{d.type}-#{d.name}"
            .attr "transform", (d) -> return "translate(#{d.x},#{d.y})"
            .classed "clicked", (d) -> d.clicked

          nodeEnter.append "text"
            .attr "class", (d) -> "node-label t-#{d.type}-#{d.name}"
            .attr "x", 0
            .attr "y", "-5px"
            .text (d) -> d.name

          nodeEnter.append "circle"
            .attr "r", radius
            .attr "cx", 0
            .attr "cy", 0
            .attr "class", (d) ->
              if d.policy == primaryPolicyId()
                return "diff-left"
              else if d.policy == comparisonPolicyId()
                return "diff-right"
            .on "mouseover", nodeMouseover
            .on "mouseout", nodeMouseout
            .on "click", nodeClick

          node.exit().remove()

        genContextItems = (data) ->
          menuItems = {}
          if data.type != 'subject'
            menuItems['show-subject'] =
              label: 'Show connected subjects'
              callback: ->
                nodeExpand(true, 'subject', data)
                redraw()
            menuItems['hide-subject'] =
              label: 'Hide connected subjects'
              callback: ->
                nodeExpand(false, 'subject', data)
                redraw()
          if data.type != 'object'
            menuItems['show-object'] =
              label: 'Show connected objects'
              callback: ->
                nodeExpand(true, 'object', data)
                redraw()
            menuItems['hide-object'] =
              label: 'Hide connected objects'
              callback: ->
                nodeExpand(false, 'object', data)
                redraw()
          if data.type != 'perm'
            menuItems['show-permission'] =
              label: 'Show connected permissions'
              callback: ->
                nodeExpand(true, 'perm', data)
                redraw()
            menuItems['hide-permission'] =
              label: 'Hide connected permissions'
              callback: ->
                nodeExpand(false, 'perm', data)
                redraw()
          if data.type != 'class'
            menuItems['show-class'] =
              label: 'Show connected classes'
              callback: ->
                nodeExpand(true, 'class', data)
                redraw()
            menuItems['hide-class'] =
              label: 'Hide connected classes'
              callback: ->
                nodeExpand(false, 'class', data)
                redraw()
          return menuItems

        d3.selectAll('.node circle').each (d) ->
            context_items = genContextItems(d)
            $(this).contextmenu
              target: '#diff-context-menu'
              items: context_items

        link = svg.select("g.links").selectAll ".link"

        # Clear the old links and redraw everything
        link.remove()

        link = svg.select("g.links").selectAll ".link"
          .data graph.links.filter((d) ->
            policyFilter = true
            for type,id of $scope.policyIds
              if id == d.policy then policyFilter = $scope.controls.links[type]
            return d.source.selected && d.target.selected && policyFilter
          ), (d,i) -> return "#{d.source.type}-#{d.source.name}-#{d.target.type}-#{d.target.name}"

        link.enter().append "line"
          .attr "class", (d) -> "link l-#{d.source.type}-#{d.source.name}-#{d.target.type}-#{d.target.name}"
          .style "stroke-width", (d) -> return d.rules.length
          .attr "x1", (d) ->
            offset = 0
            if d.source.type == "perm"
              offset = width + padding
            else if d.source.type == "object"
              offset = 2 * (width + padding)
            return d.source.x + offset
          .attr "y1", (d) -> return d.source.y - if d.source.type == "object" then height/2 else 0
          .attr "x2", (d) ->
            offset = width + padding
            if d.target.type == "object"
              offset = 2 * (width + padding)
            else if d.target.type == "class"
              offset = 3 * (width + padding)
            return d.target.x + offset
          .attr "y2", (d) -> return d.target.y - if d.target.type == "object" then height/2 else 0
          .classed "clicked", (d) -> d.source.clicked && d.target.clicked
          .classed "visible", $scope.controls.linksVisible

        link.style "stroke-width", (d) -> return linkScale(d.rules.length)

        link.exit().remove()

Set up the viewport scroll

      positionMgr = PositionManager("tl.viewport::#{IDEBackend.current_policy._id}",
        {a: 0.7454701662063599, b: 0, c: 0, d: 0.7454701662063599, e: 200, f: 50}
      )

      svgPanZoom.init
        selector: '#surface svg.diffview'
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
          g = svgPanZoom.getSVGViewport($("#surface svg.diffview")[0])
          svgPanZoom.set_transform(g, newv)
      )

      IDEBackend.add_hook "json_changed", $scope.update_view
      $scope.$on "$destroy", ->
        IDEBackend.unhook "json_changed", $scope.update_view

      start_data = IDEBackend.get_json()
      if start_data
        $scope.update_view(start_data)