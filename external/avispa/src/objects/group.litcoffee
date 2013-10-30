
Base class for "group" objects

    Avispa.Group = Avispa.BaseObject.extend
        el: () -> $SVG('g').attr('class', 'group')

        init: () ->

            @$el.append $SVG('rect')
                .attr('x', '-30')
                .attr('y', '-30')
                .attr('width',  '60')
                .attr('height', '60')

            return @
