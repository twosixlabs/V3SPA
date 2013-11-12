

    Domain = Avispa.Group.extend

        init: () ->
            @$el.append $SVG('rect')
                .attr('width',  @position.get('w'))
                .attr('height', @position.get('h'))
                .css('fill', @position.get('fill'))

            @$el.append $SVG('text')
                .attr('dx', '2em')
                .attr('dy', '1em')
                .text(@options.name)

            return @
