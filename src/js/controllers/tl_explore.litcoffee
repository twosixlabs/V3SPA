    vespaControllers = angular.module('vespaControllers')

    vespaControllers.controller 'tlCtrl', ($scope, VespaLogger,
        IDEBackend, $timeout, $modal, PositionManager, $q) ->


      diameter = 1200
      radius = diameter / 2
      innerRadius = radius - 120

      $scope.update_view = (jsondata)->

        # Ignore if empty
        unless _.size(jsondata.summary)
          return

        $scope.data = jsondata.summary

        cluster = d3.layout.cluster()
            .size([360, innerRadius])
            .sort((a, b)->
              if a.type != b.type
                comp = if a.type == 'source' then -1 else 1
              else
                d3.ascending(a.name, b.name)
            )

        bundle = d3.layout.bundle()
        line = d3.svg.line.radial()
          .interpolate('bundle')
          .tension(.85)
          .radius((d)-> d.y)
          .angle((d)->d.x / 180 * Math.PI)

        [nodes, links] = $scope.node_hierarchy($scope.data)
        nodes = cluster.nodes(nodes[""])

        node = d3.select("svg.tl_view").select('g.viewer').selectAll('.node')

        node = node.data(nodes.filter((n)-> not n.children))
        node.enter().append('text').call((selection)->
            selection.classed('node', true)
            selection.classed('type', (d)->(
              d.type == 'source' 
            ))
            selection.classed('permission', (d)->(
              d.type == 'target' 
            ))
            selection.attr("dy", ".31em")
            selection.attr("transform", (d)->
              "rotate(#{d.x - 90})translate(#{d.y + 8},0)#{if d.x < 180 then "" else "rotate(180)"}"
            )
            selection.style("text-anchor", (d)-> if d.x < 180 then "start" else "end")

            selection.text((d)->return d.name)
        )

        link = d3.select("svg.tl_view").select("g.viewer").selectAll('.link') 
        link = link.data(bundle(_.pluck(links, 'link')))
        #link.enter().append('path')
        #  .each((d, i)->
        #    key = "#{d[0].name}--#{d[d.length-1].name}"
        #    @id = key
        #  )
        #  .call((selection)->(
        #    selection.classed('link', true)
        #    selection.classed('active', (d)-> 
        #      'active' in _.pluck(links[@id].variants, 'type')
        #    )
        #    selection.classed('permitted', (d)-> 
        #      'permitted' in _.pluck(links[@id].variants, 'type')
        #    )
        #    selection.attr('d', line)
        #  )
        #)

       # tooltip = d3.select("body .popover-tooltip")

        #link.on('mouseover', (d)->
        mouseover = (d)->(
          tooltip.style('visibility', 'visible')
          linklist = $("<ul></ul>")
          _.each(links[@id].variants, (variant)->
            text = ""
            if variant.type == 'active'
              text = "#{variant.source.join(".")} has permission #{variant.target.join(".")}"
            else if variant.type == 'permitted'
              text = "#{variant.source.join(".")} permits #{variant.target.join(".")}"

            if variant.via
              text += " via attribute #{variant.via.join(".")}"

            linklist.append($( "<li>#{text}<li>"))
          )

          tooltip.html = linklist.prop('outerHTML')
        )

        #link.on('mousemove', 
        mousemove = (d)->(
          console.log("d3 mousemove")
          d3.event.preventDefault()
          tooltip.style('top', "#{event.pageY-10}px")
                 .style("left", "#{event.pageX+10}px")
          d3.event.stopPropagation()
          )
        #link.on('mouseout', 
        mouseout = (d)->(
          console.log("d3 mouseout")
          d3.event.preventDefault()
          return
          tooltip.style('visibility', 'hidden')
          d3.event.stopPropagation()
        )

Set up the viewport scroll

      positionMgr = PositionManager("tl.viewport::#{IDEBackend.current_policy._id}")

      svgPanZoom.init
          selector: '#surface svg'
          panEnabled: true
          zoomEnabled: true
          dragEnabled: false
          minZoom: 0.5
          maxZoom: 10
          onZoom: (scale, transform)->
              positionMgr.update transform
          onPanComplete: (coords, transform) ->
              console.log coords
              console.log transform
              positionMgr.update transform

        $scope.$watch(
          ->
            (positionMgr.data)
        , 
          (newv, oldv)->
            if not newv? or _.keys(newv).length == 0
              return
            g = svgPanZoom.getSVGViewport($("#surface svg")[0])
            svgPanZoom.set_transform(g, newv)
        )

      $scope.node_hierarchy = (links)->
        map = 
          "": 
            name: ""
            children: []

         #{ "source": [ "xen", "iomem_t" ], "via": null, "type": "permitted", "target": [ "resource", "use" ] }

        hierarchize = (namelist, type, map)->
          parent = namelist[0]
          child = namelist.join(".")

          parent_node = map[parent]
          unless parent_node
            map[parent] = parent_node = 
              name: parent
              children: []
              parent: map[""]

            map[""].children.push(parent_node)

          node = map[child]
          unless node
            map[child] = node = 
              name: child
              children: []
              parent: parent_node
              type: type

            map[parent].children.push(node)

          return node

        datalinks = {}
        for link in links
          src_node = hierarchize(link.source, 'source', map)
          target_node = hierarchize(link.target, 'target', map)

          key = "#{link.source.join(".")}--#{link.target.join(".")}"
          if key of datalinks
            datalinks[key].variants.push link
          else
            datalinks[key] = 
              link: 
                source: src_node
                target: target_node
              variants: [link]


        return [map, datalinks]

On load, grab the right data, etc

      IDEBackend.add_hook "json_changed", $scope.update_view
      $scope.$on "$destroy", ->
        IDEBackend.unhook "json_changed", $scope.update_view

      start_data = IDEBackend.get_json()
      if start_data
        $scope.update_view(start_data)
