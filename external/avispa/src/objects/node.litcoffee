
Base class for "node" objects

    Avispa.Node = Avispa.BaseObject.extend
        el: () -> $SVG('g').attr('class', 'node')

        init: () ->
            @$el.append $SVG('circle')
                .attr('r', '20')
                .attr('cx', '0')
                .attr('cy', '0')

            return @
