
Base class for "node" objects

    Avispa.Node = Avispa.BaseObject.extend
        el: () -> $SVG('g').attr('class', 'node')

        init: () ->
            @$el.append $SVG('circle')
                .attr('r', @position.get('radius'))
                .css('fill', @position.get('fill'))

            @$el.append $SVG('text')
                .attr('dy', '0.5em')
                .text(@options.label)

            return @
