    index_by_name = (d)->
      d.connectors = []
      d.groupName = ()-> return d.name.split('.')[1]
      @[d.name] = d

    transform = (plot, nodes)->

      plot.nodes = nodes

      plot.nodesByName = {}
      plot.nodes.forEach index_by_name, plot.nodesByName


Convert the import lists into links with sources and targets.
Save index hashes for looking up sources and targets.


      plot.links = []
      plot.sources = {}
      plot.targets = {}
      nodes.forEach (elem)->
        elem.imports.forEach (imp)->
          target = plot.nodesByName[imp]

          if not elem.source
            elem.source =
              node: elem
              degree: 0
            elem.connectors.push elem.source

          if not target.target
            target.target = 
              node: target
              degree: 0
            target.connectors.push target.target

          plot.links.push 
            source: elem.source
            target: target.target

          plot.sources[imp] ?= {}
          plot.sources[imp][elem.name] = true

          plot.targets[elem.name] ?= {}
          plot.targets[elem.name][imp] = true


      nodes.forEach (node)->
        if node.source? and node.target?
          node.type = node.source.type = 'target-source'
          node.target.type = 'source-target'
        else if node.source
          node.type = node.source.type = 'source'
        else if node.target
          node.type = node.target.type = 'target'
        else
          node.connectors = [{node: node}]
          node.type ='source'


      plot.nodesByType = d3.nest()
        .key((d)->d.type)
        .sortKeys(d3.ascending)
        .entries(nodes)

      plot.nodesByType.push(
        key: 'source-target',
        values:  plot.nodesByType[2].values 
      )

      plot.nodesByType.forEach (type)->
        count = 0
        lastName = type.values[0].groupName()

        type.values.forEach (d, i)->
          if d.groupName() != lastName
            lastName = d.groupName()
            count += 2

          d.index = count++


        type.count = count - 1

Set up the global parameters which should be used
to layout this Hive plot.

    layout = (format) ->

      degree = Math.PI / 180
      x_max = 800
      x_off = x_max * 0.5
      y_max = 800
      y_off = y_max * 0.5

      if format == 'conv'
        a_off = 20
        a_so = 0
        a_st = 120 - a_off
        a_to = -120
        a_ts = 120 + a_off
        i_rad = 25
        o_rad = 400

      else
        a_so    =  -45
        a_st    = 45
        a_to    = -135
        a_ts    = 135
        i_rad   =   25
        o_rad   = 350

      info = 
        global:
          x_max: x_max
          y_max: y_max
          x_off: x_off
          y_off: y_off
          inner_radius: i_rad
          outer_radius: o_rad

        shapes:
          node:
            shape: 'circle'
            attributes:
              r: 4

        axes:
          source:
            angle: degree * a_so
          'source-target':
            angle: degree * a_st
          "target-source":
            angle: degree * a_ts
          target:
            angle: degree * a_to

      return info

    module.exports = 
      transform: transform
      layout: layout

