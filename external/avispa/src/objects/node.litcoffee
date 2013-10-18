
Base class for "node" objects

    Avispa.Node = Avispa.BaseObject.extend
        el: $SVG('g').attr('class', 'node')

        initialize: () ->
            @$el.append $SVG('circle')
                .attr('r', '30')
                .attr('cx', '0')
                .attr('cy', '0')

            return @
