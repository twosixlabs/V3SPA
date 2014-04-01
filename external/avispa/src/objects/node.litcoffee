
Base class for "node" objects

    Avispa.Node = Avispa.BaseObject.extend
        el: () -> $SVG('g').attr('class', 'node')

        _init: () ->
            @$circle = $SVG('circle')
                .attr('r', @position.get('radius'))
                .css('fill', @position.get('fill'))
                .appendTo(@$el)

            @$label = $SVG('text')
                .attr('dy', '0.5em')
                .text(@options.label)
                .appendTo(@$el)

            return

        render: () ->
            @$circle
                .attr('cx', @position.get('x'))
                .attr('cy', @position.get('y'))

            @$label
                .attr('x', @position.get('x'))
                .attr('y', @position.get('y'))

            return @

        OnMouseEnter: (event) ->
            if not context.dragItem?
                @$circle.attr('class', 'hover')

                context.ide_backend.highlight(@options.data)

            return cancelEvent(event)

        OnMouseLeave: (event) ->
            if not context.dragItem?
                @$circle.removeAttr('class')
                context.ide_backend.unhighlight()

            return cancelEvent(event)


        Drag: (event) ->
            new_x = (event.clientX / context.scale) - @clickOffsetX
            new_y = (event.clientY / context.scale) - @clickOffsetY

            new_positions = 
              x: new_x 
              y: new_y 

            @EnforceBoundingBox new_positions

            return cancelEvent(event)
