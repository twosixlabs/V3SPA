    HiveLink = require './lib_link'
    mouse = require './mouse'

    class HivePlot
      constructor: (@selector, @info)->
        @angle_dom = []
        @angle_rng = []

        g = @info.global

        for name, axis of info.axes
          do (name, axis)=>
            @angle_dom.push name
            @angle_rng.push axis.angle

        @angle_f = d3.scale.ordinal().domain(@angle_dom).range(@angle_rng)

        @radius_f = d3.scale.linear().range [g.inner_radius, g.outer_radius]

        @color_f = d3.scale.category10()

        transform = "translate(#{g.x_off}, #{g.y_off})"

        # Clean up the svg if it exists already
        d3.select("#{@selector} svg").remove()

        @svg = d3.select("#{@selector}")
                    .append('svg')
                    .attr('width', "100%")
                    .attr('height', g.y_max)
                    .append('g')
                    .attr('transform', transform)
                    .attr('id', 'viewport')

      degrees: (radians) ->
        radians / Math.PI * 180 - 90

      display: ->

        if @nodes.length == 0
          warning = @svg.selectAll('.warning')
            .data([{warning: "Insufficient top-level data to render hive plot"}])
            .enter()
            .append('text')
          warning.text((d)->(d.warning))
            .attr("fill", "red")
          return


Set the radius domain

        extent = d3.extent @nodes, (d)->
          return d.index

        @radius_f.domain(extent)

Draw the axes

        transform = (d)=>
          return "rotate(#{@degrees(@angle_f(d.key))})"

        x1 = @radius_f(0) - 10
        x2 = (d)=>
          @radius_f(d.count * 2 ) + 10

        axes = @svg.selectAll('.axis')
          .data(@nodesByType)

        axes.enter().append('line')
            .attr('class', 'axis')
            .attr('transform', transform)
            .attr('x1', x1)
            .attr('x2', x2);

Draw links

        path_angle = (d)=>
          @angle_f(d.type)

        path_radius = (d)=>
          @radius_f(d.node.index)

        lines = @svg.append('g')
          .attr('class', 'links')
          .selectAll('.link')
          .data(@links)

        lines.enter().append('path')
            .attr('d', HiveLink().angle(path_angle).radius(path_radius) )
            .attr('class', 'link')
            .on('mouseover', mouse.on_mouseover_link)
            .on('mouseout',  mouse.on_mouseout);

Draw the nodes. Note that each can have up to two connectors representing the
source and target links.

        connectors = (d) -> return d.connectors
        cx = (d)=> @radius_f(d.node.index)
        fill = (d) => @color_f(d.groupName())

        transform = (d)=>
          return "rotate(#{@degrees(@angle_f(d.type))})"

        node_shape = @info.shapes.node

        drawn_nodes = @svg.append('g')
          .attr('class', 'nodes')
          .selectAll('.node')
          .data(@nodes)
          .enter().append('g')
            .attr('class', 'node')
            .style('fill', fill)
            .selectAll(node_shape.shape)
            .data(connectors)
            .enter().append(node_shape.shape)

        for attr, val of node_shape.attributes
          drawn_nodes.attr(attr, val)

        drawn_nodes.attr('transform', transform)
              .attr('class', 'node_shape')
              .attr('cx', cx)
              .on('mouseover', mouse.on_mouseover_node)
              .on('mouseout',  mouse.on_mouseout);


    module.exports = HivePlot
