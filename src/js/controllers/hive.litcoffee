    vespaControllers = angular.module('vespaControllers')

    vespaControllers.controller 'hiveCtrl', ($scope, VespaLogger, IDEBackend, PositionManager)->
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
      turtlesAllTheWayDown = (d3Selection, startDomain, rawData, depth)->(

        #/* This part handles this levels display */
        box = d3Selection.append('g')
        box.append('rect')
            .attr('fill', '#99ccff')
            .attr('width', config.width)
            .attr('height', (d)->(
                if d.leafCount and d.leafCount > 0
                  return (d.leafCount) * config.leafSize * 1.40

                else
                  return config.leafSize
            ))

        box.append('text')
            .text(config.textFn)
            .attr('font-size', '16')
            .style('text-anchor', 'middle')
              #//.style('dominant-baseline', 'middle')
            .attr('x', config.width / 2)
            .attr('y', (d)->(
              if d.leafCount
                (d.leafCount * config.leafSize / 2) + (config.leafSize / 2) + 5
              else
                return config.leafSize / 2 + 5
            ))


        #/* The rest of this function handles subdomains */
        nextLevel = d3Selection.selectAll("#{config.elemType}.subdomGroup")
            .data(_.map(startDomain.subdomains, (v, k)->
              if k of rawData.domains
                rawData.domains[k]
              else
                { dom_id: k, name: v.name}
            ))

        nextLevel
          .enter().append(config.elemType)
            .classed('subdomGroup', true)
            .attr('transform', (d, i)->(
              "translate(#{config.width * 1.25 * depth}, #{i * config.leafSize * 1.4})"
            ))

        #/* Recursively call this function for subdomains */
        nextLevel.each (d, i)->(
          turtlesAllTheWayDown(d3.select(@), d, rawData, depth + 1);
        )
      )

      update_listener = (json_data)->

        if not json_data.result?
          return

        positionMgr = PositionManager("hive.viewport::#{IDEBackend.current_policy._id}")

        total_size = leafCount("0", json_data.result)

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
                            return leafCount(d.id, json_data.result)
                        )
                        .children((d)->(
                          ret = _.union(
                            _.map(d.subdomains, (sub, id)->(
                              if id of json_data.result.domains
                                x = json_data.result.domains[id]
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
                              x = json_data.result.ports[port]
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

        startDomain = json_data.result.domains["0"];
        nodes = partition.nodes(startDomain)
        color = d3.scale.ordinal().domain([null, 'port','domain']).range([
          '#d9d9d9', '#e5c494', '#ffd92f'
        ])
        fontsize = d3.scale.log().rangeRound([3, 16]).domain([10, layout.w]).clamp(true)

        svg_container = $('svg.hiveview')[0]
        segment = d3.select("svg.hiveview").select('g.viewer')
          .selectAll('g')
          .data(nodes, (d)-> 
            return d.path)

        x_position = (d)->
          d.y + (6 * d.depth)

        segment.select('rect').transition()
          .attr('x', x_position)
          .attr('y', (d)->d.x)
          .attr('width', (d)->d.dy)
          .attr('height', (d)->d.dx)
          .style('fill', (d)->
            return color(d.type)
          )

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
          .classed('domains', (d)-> d.type == 'domain')
          .transition().delay(500) 
          .attr('x', x_position)
          .attr('y', (d)->d.x)
          .attr('width', (d)->d.dy)
          .attr('height', (d)->d.dx)
          .style('fill', (d)->
            return color(d.type)
          )
          .style('stroke', '1px solid #ccc')

        group.append('text').transition().delay(500)
          .text((d)->d.name)
          .attr('text-anchor', 'middle')
          .attr('font-size', (d)->fontsize(d.dx))
          .attr('x', (d)-> x_position(d) + (d.dy / 2))
          .attr('y', (d)-> d.x + (d.dx / 2) + (0.5 * fontsize(d.dx)))


        segment.exit().remove()

        segment.on('mousedown', (d, i)->
          d.clicked_at = d3.mouse(svg_container)
          #d3.event.stopPropagation()
        )

        segment.on('mouseup', (d, i )->
          if not _.isEqual( d.clicked_at, d3.mouse(svg_container))
            d.clicked_at = null
            return

          if d.children
            IDEBackend.contract_graph_by_id _.pluck(d.children, 'id').concat(d.id)
          else
            IDEBackend.expand_graph_by_id [d.id]
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

        rawData = json_data.result;
        firstLevel = d3.select("svg.hiveview").append('g').classed('viewer', true)
            .selectAll('g.subdomGroup')
            .data(_.map(startDomain.subdomains, (v, k)->
              if k of rawData.domains
                rawData.domains[k]
              else
                { dom_id: k, name: v.name}
            ))

        firstLevel
          .enter().append(config.elemType)
            .classed('subdomGroup', true)
            .attr('transform', (d, i)->(
              "translate(#{config.width * 1.25}, #{i * config.leafSize * 1.4})"
            ))

        `
          firstLevel.each(function(d, i){
            turtlesAllTheWayDown(d3.select(this), d, rawData, 1);
          });
        `

      IDEBackend.add_hook 'json_changed', update_listener
      $scope.$on '$destroy', ->
        IDEBackend.unhook('json_changed', update_listener)

      start_data = IDEBackend.get_json()
      if start_data
        update_listener(start_data)
