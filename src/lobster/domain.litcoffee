

    Domain = Avispa.Group.extend

        init: () ->
            @$label = $SVG('text')
                .attr('dx', '0.5em')
                .attr('dy', '1.5em')
                .text(@options.name)
                .appendTo(@$el)

            return @

        render: () ->
            @$rect
                .attr('x', @position.get('x'))
                .attr('y', @position.get('y'))
            @$label
                .attr('x', @position.get('x'))
                .attr('y', @position.get('y'))
            return @

