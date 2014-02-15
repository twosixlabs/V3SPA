    templates = 
      node_tooltip: require('./node_tooltip.jade')
      link_tooltip: require('./link_tooltip.jade')

    TransformData = (plot, data)->

      domain_ids = {}

      plot.connections = {}
      plot.nodes ?= []
      plot.nodesByName ?= {}

      for id, subd of data.subdomains
        do (id, subd)->
          for port of subd.ports
            do (port)->
              node = 
                domain: subd
                port: port
                name: "#{subd.name}.#{port}" 
                groupName: ()-> return subd
                connectors: []
                connectorByType: {}

              plot.nodes.push node
              plot.nodesByName[node.name] = node
              domain_ids[id] = subd

              plot.connections[node.name] = 
                neutral: []
                inbound: []
                outbound: []

Convert the connections listed in the domain into links with
sources and targets.

      plot.links = []

      node_by_id_port = (id, port)->
        domain = domain_ids[id]
        return plot.nodesByName["#{domain.name}.#{port}"]

      data.connections.forEach (conn)->
        left_node = node_by_id_port(conn.left.domain, conn.left.port)
        right_node = node_by_id_port(conn.right.domain, conn.right.port)

        add_connector = (node, type)->
          node.connectorByType[type] ?=
            node: node
            type: type

        if conn.connection == 'neutral'

          plot.connections[left_node.name].neutral.push right_node.name
          plot.connections[right_node.name].neutral.push left_node.name


          add_connector left_node, 'neutral_inbound'
          add_connector right_node, 'neutral_outbound'
          add_connector left_node, 'neutral_outbound'
          add_connector right_node, 'neutral_inbound'

          plot.links.push
            source: left_node.connectorByType.neutral_inbound
            target: right_node.connectorByType.neutral_outbound
            type: 'neutral'

          plot.links.push
            source: right_node.connectorByType.neutral_inbound
            target: left_node.connectorByType.neutral_outbound
            type: 'neutral'

        if conn.connection == 'left-to-right'

          plot.connections[left_node.name].outbound.push right_node.name
          plot.connections[right_node.name].inbound.push left_node.name

          add_connector left_node, 'directed'
          add_connector right_node, 'neutral_inbound'

          plot.links.push 
            source: left_node.connectorByType.directed
            target: right_node.connectorByType.neutral_inbound
            type: 'outbound'

          add_connector left_node, 'neutral_outbound'
          add_connector right_node, 'directed'

          plot.links.push 
            source: left_node.connectorByType.neutral_outbound
            target: right_node.connectorByType.directed
            type: 'inbound'


        if conn.connection == 'right-to-left'

          plot.connections[right_node.name].outbound.push left_node.name
          plot.connections[left_node.name].inbound.push right_node.name

          add_connector right_node, 'directed'
          add_connector left_node, 'neutral_outbound'

          plot.links.push 
            source: right_node.connectorByType.directed
            target: left_node.connectorByType.neutral_outbound
            type: 'inbound'

We actually want all of the nodes to appear on all axes if necessary,
and ideally in the same place on all of them, so simply index them from
1.

Create nodesByType manually, for layout purposes. Our nodes aren't actually
differentiated by type

      plot.nodes.forEach (node, i)->
        for axis, n of node.connectorByType
          do (axis, n)->
            node.connectors.push(n)
        node.index  = i *2

      plot.nodesByType = [
          key: 'directed'
          count: plot.nodes.length
        ,
          key: 'neutral_inbound'
          count: plot.nodes.length
        ,
          key: 'neutral_outbound'
          count: plot.nodes.length
      ]


    Layout = (format)->

      degree = Math.PI / 180
      x_max = 800
      x_off = x_max * 0.5
      y_max = 700
      y_off = y_max * 0.6

      if format == 'conv'
        a_off = 20
        a_so = 0
        a_st = 120
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

Highlighters contains the information required for the mouseover
library to properly highlight elements. There is a separate
highligher for nodes and links.

For both nodes and links highlighting can be defined, as an object where the
keys are a class to be applied, and the values are a function that when true,
the class will be applied to the object. The ident function has a signature as
follows: `ident = function(mouseover_node, node, plot_object)`.

        highlighters:
          nodes:
            node:
              active_mo: (node, mo_node, plot)->
                  return mo_node.node.name == node.node.name
              active_ob: (node, mo_node, plot)->
                  return node.node.name in plot.connections[mo_node.node.name].outbound
              active_ib: (node, mo_node, plot)->
                  return node.node.name in plot.connections[mo_node.node.name].inbound

            link:
              active_neutral: (link, mo_node, plot)->
                node_name = mo_node.node.name
                if link.type == 'neutral'
                  return link.target.node.name == node_name or link.source.node.name == node_name
                return false
              active_ib: (link, mo_node, plot)->
                if link.type == 'inbound'
                  return link.source.node.name in plot.connections[mo_node.node.name].inbound
              active_ob: (link, mo_node, plot)->
                if link.type == 'outbound'
                  return link.target.node.name in plot.connections[mo_node.node.name].outbound
          links:
            active_mo: (link, mo_link, plot)->
              return link == mo_link

        tooltip:
          node: templates.node_tooltip
          link: templates.link_tooltip
        axes:
          "neutral_inbound":
            angle: degree * a_to
          "neutral_outbound":
            angle: degree * a_st
          directed:
            angle: degree * a_so

      return info

    module.exports = 
      transform: TransformData
      layout: Layout

