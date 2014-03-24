
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

            if @parent

                ppos = 
                  x: @parent.position.get('x')
                  y: @parent.position.get('y')
                  w: @parent.position.get('w')
                  h: @parent.position.get('h')

                if new_positions.x < ppos.x
                    new_positions.x = ppos.x
                else if new_positions.x > ppos.x + ppos.w
                    new_positions.x = ppos.x + ppos.w

                if new_positions.y < ppos.y
                    new_positions.y = ppos.y
                else if new_positions.y > ppos.y + ppos.h
                    new_positions.y = ppos.y + ppos.h

                new_positions.offset_x = new_positions.x - ppos.x
                new_positions.offset_y = new_positions.y - ppos.y

            @position.set new_positions

            return cancelEvent(event)
