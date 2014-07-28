    vespaControllers = angular.module('vespaControllers')

    vespaControllers.controller 'tlCtrl', ($scope, VespaLogger,
        IDEBackend, $timeout, $modal, PositionManager, $q) ->

      $scope.data = null
      $scope.visibility =
        active: true
        permitted: true

      $scope.$watchCollection 'visibility', (newv, oldv)->
        $scope.update_view($scope.data)

      diameter = 1200
      radius = diameter / 2
      innerRadius = radius - 120

      $scope.update_view = (jsondata)->

        # Ignore if empty
        unless jsondata and _.size(jsondata.summary)
          return

        $scope.data = jsondata

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


        # Define the nodes and links
        [nodes, links] = $scope.node_hierarchy($scope.data.summary)
        nodes = cluster.nodes(nodes[""])

        node = d3.select("svg.tl_view").select('g.viewer').selectAll('.node')
        node = node.data(nodes.filter((n)-> not n.children), (d, i)->
          d.name
        )
        link = d3.select("svg.tl_view").select("g.viewer").selectAll('.link') 
        link = link.data(bundle(_.pluck(links, 'link')), (d, i)->
          "#{d[0].name}--#{d[d.length-1].name}"
        )

        node_selection_update = (selection)->(
            selection.transition().attr("transform", (d)->
              "rotate(#{d.x - 90})translate(#{d.y + 8},0)#{if d.x < 180 then "" else "rotate(180)"}"
            )
            selection.style("text-anchor", (d)-> if d.x < 180 then "start" else "end")

        )

        link_selection_update = (selection)->(
            selection.transition().attr('d', line)
            selection.classed('active', (d)-> 
                'active' in _.pluck(links[@id].variants, 'type')
              )
            selection.classed('permitted', (d)-> 
                'permitted' in _.pluck(links[@id].variants, 'type')
              )
          )

        # Node update
        node.call(node_selection_update)

        # Link update
        link.call(link_selection_update)

        node.enter().append('text').call(node_selection_update)
            .text((d)->return d.name)
            .attr('id', (d)->
              "#{d.name}"
            )
            .classed('node', true)
            .classed('type', (d)->(
              d.type == 'source' 
            ))
            .classed('permission', (d)->(
              d.type == 'target' 
            ))
            .attr("dy", ".31em")

        link.enter().append('path').each((d, i)->
            key = "#{d[0].name}--#{d[d.length-1].name}"
            @id = key
          )
          .call(link_selection_update)
          .classed('link', true)

        node.exit().transition().remove()
        link.exit().transition().style('stroke-opacity', 0).remove()

        tooltip = d3.select("body .popover-tooltip")

        addClass = (node, klass)->
          node.attr('class', (idx, current)->
            return current + " #{klass}"
          )

        removeClass = (node, klass)->
          current = node.attr('class').split(' ')
          node.attr('class', _.filter(current, (x)->(x != klass)).join(' '))

        showTooltip = (ttip, lines, formatter)->
          linklist = $("<ul class='list-unstyled'></ul>")

          _.each(lines, (line)->
            text = formatter(line)
            linklist.append($.parseHTML("<li>#{text}</li>"))
          )
          ttip.html(linklist.prop('outerHTML'))
          ttip.style('visibility', 'visible')


        mouseover_link = (d)->(
          showTooltip(tooltip, links[@id].variants, (variant)->
            text = ""
            if variant.type == 'active'
              text = "#{variant.source.join(".")} <em>has permission</em> #{variant.target.join(".")}"
            else if variant.type == 'permitted'
              text = "#{variant.target.join(".")} <em>is permitted on </em> #{variant.source.join(".")}"

            if variant.via
              text += " <em>via attribute</em> #{variant.via.join(".")}"

            return text
          )

          origin = $(document.getElementById(d[0].name))
          end = $(document.getElementById(d[d.length-1].name))

          addClass(origin, 'bold')
          addClass(end, 'bold')

          addClass($(@), 'thick')

        )
        link.on('mouseover', mouseover_link)

        mousemove = (d)->(
          d3.event.preventDefault()
          tooltip.style('top', "#{event.pageY-10}px")
                 .style("left", "#{event.pageX+10}px")
                 .style("bottom", null)
                 .style("right", null)

          d3.event.stopPropagation()
        )
        link.on('mousemove', mousemove) 

        mouseout_link = (d)->(
          tooltip.style('visibility', 'hidden')
          origin = $(document.getElementById(d[0].name))
          end = $(document.getElementById(d[d.length-1].name))

          removeClass(origin, "bold")
          removeClass(end, "bold")
          removeClass($(@), 'thick')

          d3.event.stopPropagation()
        )
        link.on('mouseout',  mouseout_link)



        getAbsPos = (elem)->
          pos = 
            x: 0
            y: 0

          loop
            pos.x += elem.getBBox().x
            pos.y += elem.getBBox().y

            elem = elem.parentElement
            break unless elem

          return pos

        node.on('mouseover', (d)->
          tooltip_data_elems =  _.map(links, (link, link_name)->
            unless _.any(link.variants, (x)-> $scope.visibility[x.type])
              return null

            if d.name not in [link.link.source.name, link.link.target.name]
              return null# Not related

            link_elem = $(document.getElementById(link_name))
            addClass(link_elem, 'thick')

            return link.variants
          )

          tooltip_data_elems = _.flatten(_.filter(tooltip_data_elems, (e)-> e != null))

          bbox = @getBoundingClientRect()
          offset_x = Math.abs(20 * Math.cos(d.x))
          offset_y = Math.abs(20 * Math.sin(d.x))

          if d.x > 180
            tooltip.style("left", null)
            tooltip.style("right", "#{window.innerWidth - bbox.left + offset_x}px")
          else
            tooltip.style("left", "#{bbox.right + offset_x}px")
            tooltip.style("right", null)

          if (d.x + 90) % 360 > 180
            tooltip.style('top', "#{bbox.bottom + offset_y}px")
            tooltip.style('bottom', null)
          else
            #top = bbox.top - bbox.height
            tooltip.style('bottom', "#{window.innerHeight - bbox.top + offset_y}px")
            tooltip.style('top', null)


          showTooltip(tooltip, tooltip_data_elems, (variant)->
            text = ""
            if variant.type == 'active'
              text = "#{variant.source.join(".")} <em>has permission</em> #{variant.target.join(".")}"
            else if variant.type == 'permitted'
              text = "#{variant.target.join(".")} <em>is permitted on </em> #{variant.source.join(".")}"

            if variant.via
              text += " <em>via attribute</em> #{variant.via.join(".")}"

            return text                              
          )
          addClass($(@), 'bold')
          d3.event.stopPropagation()
        )

        node.on('mousemove', (d)->
          d3.event.preventDefault()

          d3.event.stopPropagation()
        )

        node.on('mouseout', (d)->
          tooltip.style('visibility', 'hidden')
          tooltip_data_elems =  _.each(links, (link, link_name)->
            unless _.any(link.variants, (x)-> $scope.visibility[x.type])
              return null

            if d.name not in [link.link.source.name, link.link.target.name]
              return null# Not related

            link_elem = $(document.getElementById(link_name))
            removeClass(link_elem, 'thick')
          )

          removeClass($(@), 'bold')
          d3.event.stopPropagation()
        )

Set up the viewport scroll

        positionMgr = PositionManager("tl.viewport::#{IDEBackend.current_policy._id}",
          {a: 0.7454701662063599, b: 0, c: 0, d: 0.7454701662063599, e: 504.606201171875, f: 546.9595947265625}
        )

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
          unless $scope.visibility[link.type]
            continue 

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
