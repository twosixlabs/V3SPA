    module.exports = {}
    module.exports.setup_mouse = (plot, tooltip_fn) ->

Initialize info display

      formatNumber = d3.format ',d'
      indent = "&nbsp;&nbsp;"

      notes = tooltip_fn

      module.exports.on_mouseout = ->
        for highlighter of plot.info.highlighters.nodes.node
          plot.svg.selectAll(".#{highlighter}").classed(highlighter, false)
        for highlighter of plot.info.highlighters.nodes.link
          plot.svg.selectAll(".#{highlighter}").classed(highlighter, false)
        for highlighter of plot.info.highlighters.links
          plot.svg.selectAll(".#{highlighter}").classed(highlighter, false)

        # Callback with null to notify that there's no mouseover.
        notes(null)


      module.exports.on_mouseover_h = (css_class, html_inp)->

        if not html_inp
          return ''

        if css_class == 'ib'
          hdr = '<h4 class="ib"> Imported by: </h4>'
        else
          hdr = '<h4 class="im"> Imports:</h4>'

        return "<span class='#{css_class}'> #{hdr} #{html_inp} </span>"

For links, highlight them and their connected nodes when you mouseover

      module.exports.on_mouseover_link = (orig_link)->

        for cls, ident_fn of plot.info.highlighters.links
          do (cls, ident_fn)->

            cond = (link)->
              ident_fn(link, orig_link, plot)

            plot.svg.selectAll(".link").classed(cls, cond)

        html = plot.info.tooltip.link {link: orig_link, plot: plot}


        notes(html);


Highlight the node and connected links on mouseover.

Mousing over a node should cause:

- the node (and its clone, if any)    to turn red
- the links and nodes that it imports to turn green
- the links and nodes that import it  to turn blue
- the sidebar to show consistent colors and text

      module.exports.on_mouseover_node = (orig_node)->

        for cls, ident_fn of plot.info.highlighters.nodes.link
          do (cls, ident_fn)->

            cond = (link)->
              ident_fn(link, orig_node, plot)

            plot.svg.selectAll(".link").classed(cls, cond)

        for cls, ident_fn of plot.info.highlighters.nodes.node
          do (cls, ident_fn)->

            cond = (node)->
              ident_fn(node, orig_node, plot)

            plot.svg.selectAll(".node .node_shape").classed(cls, cond)

        html = plot.info.tooltip.node {node: orig_node.node, plot: plot}

        notes(html)

