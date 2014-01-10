
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
            return cancelEvent(event)

        OnMouseLeave: (event) ->
            if not context.dragItem?
                @$circle.removeAttr('class')
            return cancelEvent(event)


        Drag: (event) ->
            x = (event.clientX / context.scale) - @x1
            y = (event.clientY / context.scale) - @y1

            if @offset
                @offset.x = @ox1 + x
                @offset.y = @oy1 + y

                if @offset.x < 0
                    @offset.x = 0
                    x = @parent.position.get('x')
                else if @offset.x > @parent.position.get('w')
                    @offset.x = @parent.position.get('w')
                    x = @parent.position.get('x') + @parent.position.get('w')
                if @offset.y < 0
                    @offset.y = 0
                    y = @parent.position.get('y')
                else if @offset.y > @parent.position.get('h')
                    @offset.y = @parent.position.get('h')
                    y = @parent.position.get('y') + @parent.position.get('h')

            @position.set 'x': x, 'y': y

            return cancelEvent(event)
