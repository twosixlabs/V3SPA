    vespaControllers = angular.module('vespaControllers')

    vespaControllers.controller 'hiveCtrl', ($scope, $modal, $timeout, VespaLogger, IDEBackend, PositionManager)->


      $scope.analysisPaneVisible = false
      $scope.clearAnalysis = ->
          $scope.analysisPaneVisible = false
          $scope.analysisData = null

      $scope.highlight = (data)->
          _.each data.hops, (conn)->
              conn_select = $scope.objects.connections[conn.conn]
              conn_select.classed('svg-highlight-reach-0', true)

              remove_highlight = ->
                  conn_select.classed('svg-highlight-reach-0', false)

              $timeout remove_highlight, 10000

      $scope.has_context = (data)->

          if data.type == 'port'
            return not _.contains(
              ['member_obj', 'member_subj', 'attribute_subj', 'attribute_obj', 'module_subj', 'module_obj'],
              data.name)
          else
            return false


      $scope.start_reachability_query = (port, data)->

        $scope.analysisOrigin = data.parent.name

        instance = $modal.open
            templateUrl: 'analysisModal.html'
            controller: 'modal.analysis_controls'
            resolve:
              origin_id_accessor: ->
                (port_data)->
                  port_data.parent.id
              port_data: ->
                data

        instance.result.then(
          (paths)-> 
            if _.isEmpty(_.omit(paths, 'truncated'))
              $.growl(
                title: "Info"
                message: "Analysis returned no results."
              ,
                type: 'info'
              )

            else

              $scope.analysisData = paths
              $scope.analysisPaneVisible = true
        )

      $scope.create_context_menu = (port, data)->

        current_menu = $(port).data('context')
        current_menu.destroy() if current_menu

        items = {}
        if data.type == 'port'
            items['display_reachability'] = 
                label: "Analyze Reachability"
                callback: ->
                    $scope.start_reachability_query(port, data)

        if data.srcloc
            items['jump-to-code'] = 
                label: "Show Code"
                callback: ->
                    IDEBackend.highlight(data)
                    $timeout IDEBackend.unhighlight, 5000

        $(port).contextmenu
          target: '#hive-context-menu'
          items: items 
          before: (e, context)->
            invalid = ['member_obj', 'member_subj', 'attribute_subj',
                          'attribute_obj', 'module_subj', 'module_obj']
            if _.contains(invalid, data.name)
              return false

            return true

      `
      function leafCount(domain_id, rawData) {
        var domain = rawData.domains[domain_id];

        var memo = 0

        if (typeof domain !== 'undefined') {
          memo = _.reduce(domain.subdomains, function(memo, v, k) {
            return memo + leafCount(k, rawData);
          }, 0);

          //rawData.domains[domain_id].leafCount = memo;
        }

        return memo + 1;
      }

      var config = {
        elemType: "g",
        textFn: function (d) { console.log(d.name); return d.name; },
        leafSize: 20,
        width: 200
      };

      `

      update_listener = (json_data)->

        # Hive uses the parameterized JSON data
        json_data = json_data.parameterized

        if not json_data?
          return

        $scope.objects =
          connections: []
          ports: []
          domain: []

        positionMgr = PositionManager("hive.viewport::#{IDEBackend.current_policy._id}")

        total_size = leafCount("0", json_data)

        layout =
          w: 1600
          h: 1000

        partition = d3.layout.partition()
                        .size([layout.w, layout.h])
                        .sort((a, b)->
                          d3.ascending(a.name, b.name)
                        )
                        .value((d)->
                          if d.type == 'port'
                            return 1
                          else
                            return leafCount(d.id, json_data)
                        )
                        .children((d)->(
                          ret = _.union(
                            _.map(d.subdomains, (sub, id)->(
                              if id of json_data.domains
                                x = _.clone json_data.domains[id]
                                x.type = 'domain'
                                x.id = id
                                x
                                
                              else
                                ret = 
                                  type: 'domain'
                                  name: sub.name
                                  id: id
                                  path: if d.path == "" then sub.name else "#{d.path}.#{sub.name}"
                            ))
                          ,
                            _.map(d.ports, (port)->(
                              x = _.clone json_data.ports[port]
                              x.id = port
                              x.type = 'port'
                              x
                            ))
                          )
                          if _.size(ret) == 0
                            return null
                          else
                            return ret
                        ))

        startDomain = _.clone(json_data.domains["0"])

        nodes = partition.nodes(startDomain)

        portsById = _.indexBy(_.filter(nodes, (d)-> d.type == 'port'), 'id')
        color = d3.scale.ordinal().domain([null, 'port','domain']).range([
          '#d9d9d9', '#e5c494', '#ffd92f'
        ])
        fontsize = d3.scale.log().rangeRound([4, 16]).domain([10, layout.w]).clamp(true)
        curve_control = d3.scale.sqrt()
          .rangeRound([250, 1000])
          .domain([10, layout.h])

        svg_container = $('svg.hiveview')[0]
        segment = d3.select("svg.hiveview").select('g.viewer').select('g#nodes')
          .selectAll('g')
          .data(nodes, (d)-> 
            return d.path)

        x_position = (d)->
          d.y + (3 * d.depth)

        set_classes = (selection)->
          selection.classed('domains', (d)-> d.type == 'domain')
                   .classed('ports', (d)-> d.type == 'port')
                   .classed('contextual', (d)-> $scope.has_context(d))
                   .classed('contractable', (d)->( d.type == 'domain' and d.children))

        segment.select('rect')
          .call(set_classes)
          .transition()
          .attr('x', x_position)
          .attr('y', (d)->d.x)
          .attr('width', (d)->d.dy)
          .attr('height', (d)->d.dx)
          .style('fill', (d)->
            if d.type == 'port' and d.name =='active'
              return "#e6ab02"
            else
              return color(d.type)
          )
          .each((d ,i)->(
              $scope.create_context_menu(@, d)
          ))

        segment.select('text').transition()
          .text((d)->d.name)
          .attr('text-anchor', 'middle')
          .attr('font-size', (d)->
            fontsize(d.dx)
          )
          .attr('x', (d)-> x_position(d) + (d.dy / 2))
          .attr('y', (d)-> d.x + (d.dx / 2) + (0.5 * fontsize(d.dx)))

        group = segment.enter().append('g')
        group.append('rect')
          .call(set_classes)
          .transition().delay(500) 
          .attr('x', x_position)
          .attr('y', (d)->d.x)
          .attr('width', (d)->d.dy)
          .attr('height', (d)->d.dx)
          .style('fill', (d)->
            if d.type == 'port' and d.name =='active'
              return "#e6ab02"
            else
              return color(d.type)
          )
          .each((d ,i)->(
              if d.srcloc
                console.log "Add context #{d.path} with srcloc"
              $scope.create_context_menu(@, d,)
          ))

        group.append('text').transition().delay(500)
          .text((d)->d.name)
          .attr('text-anchor', 'middle')
          .attr('font-size', (d)->fontsize(d.dx))
          .attr('x', (d)-> x_position(d) + (d.dy / 2))
          .attr('y', (d)-> d.x + (d.dx / 2) + (0.5 * fontsize(d.dx)))


        segment.exit().remove()

        segment.on('mousedown', (d, i)->
          d.click_event = 
            location: d3.mouse(svg_container)
            event: d3.event
        )

        segment.on('mouseup', (d, i )->
          unless d.click_event
            return

          if d.click_event.event.button == 2
            return

          if not _.isEqual( d.click_event.location, d3.mouse(svg_container))
            d.click_event = null
            return

          if d.type == 'port'
            return

          if d.children
            d3.select(@).select('rect').classed(
              contractable: false
            )
            IDEBackend.contract_graph_by_id _.pluck(d.children, 'id').concat(d.id)
          else
            d3.select(@).select('rect').classed(
              contractable: true
            )
            IDEBackend.expand_graph_by_id [d.id]
        )

        link_data = _.map(json_data.connections, (conn, k)->
          unless conn.left of json_data.ports and conn.right of json_data.ports
            return null

          conn.id = k
          return conn
        )
        link_data = _.without(link_data, null)

        links = d3.select("svg.hiveview").select('g.viewer').select('g#links')
          .selectAll('path').data(link_data, (d)->d.id)

        link_path_fn = (d)->
            left_port = portsById[d.left]
            right_port = portsById[d.right]
            rm_coords = (port)->
              [x_position(port) + port.dy, port.x + (port.dx / 2)]

            lcoord = rm_coords(left_port)
            rcoord = rm_coords(right_port)
            vdist = Math.abs(lcoord[1] - rcoord[1])
            hdist = Math.abs(lcoord[0] - rcoord[0])
            top_point = if lcoord[1] > rcoord[1] then rcoord[1] else lcoord[1]

            path = "M #{lcoord[0]} #{lcoord[1]}" 
            path +=" Q #{lcoord[0] + curve_control(vdist) + hdist} #{top_point + (0.5 * vdist)}"  # control point 1
            path += " #{rcoord[0]} #{rcoord[1]}" # end point
            path

        links.transition()
          .attr('d', link_path_fn)
          .each( (d)->
              $scope.create_context_menu(@, d)
          )

        links.enter()
          .append('path')
          .each( (d)->
              $scope.create_context_menu(@, d)
          )
          .transition().delay(500)
          .attr('d', link_path_fn)

        links.exit().transition().remove()

        links.each (d)->(
            $scope.objects.connections[d.id] = d3.select(@)
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

        return

      IDEBackend.add_hook 'json_changed', update_listener
      $scope.$on '$destroy', ->
        IDEBackend.unhook('json_changed', update_listener)

      start_data = IDEBackend.get_json()
      if start_data
        update_listener(start_data)

      return
