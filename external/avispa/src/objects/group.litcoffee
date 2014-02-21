
Base class for "group" objects

    Avispa.Group = Avispa.BaseObject.extend
        el: () -> $SVG('g').attr('class', 'group')

        _init: () ->
            @$rect = $SVG('rect')
                .attr('width',  @position.get('w'))
                .attr('height', @position.get('h'))
                .css('fill', @position.get('fill'))
                .appendTo(@$el)

            return

        render: () ->
            #@$el.attr('transform', "translate(#{@position.get('x')}, #{@position.get('y')})")
            @$rect
                .attr('x', @position.get('x'))
                .attr('y', @position.get('y'))
            return @

        OnMouseEnter: (event) ->
            if not context.dragItem?
                @$rect.attr('class', 'hover')
            return cancelEvent(event)

        OnMouseLeave: (event) ->
            if not context.dragItem?
                @$rect.removeAttr('class')
            return cancelEvent(event)


        Drag: (event) ->
            new_positions =
              x: (event.clientX / context.scale) - @clickOffsetX 
              y: (event.clientY / context.scale) - @clickOffsetY


If we have a parent element, we want to make sure that our box is at least
10 pixels inside of it at all times. We start by calculating the amount of
space space there is around the edges of this group.

            if @parent
                ppos = 
                  x: @parent.position.get('x')
                  y: @parent.position.get('y')
                  w: @parent.position.get('w')
                  h: @parent.position.get('h')

                boundsx = @parent.position.get('w') - @position.get('w') - 10
                boundsy = @parent.position.get('h') - @position.get('h') - 10

                if new_positions.x < (ppos.x + 10)
                    new_positions.x = ppos.x + 10
                else if new_positions.x - ppos.x > boundsx
                    new_positions.x = ppos.x + boundsx

                if new_positions.y < (ppos.y + 10)
                    new_positions.y = ppos.y + 10
                else if new_positions.y - ppos.y > boundsy
                    new_positions.y = ppos.y + boundsy

                new_positions.offset_x = new_positions.x - ppos.x
                new_positions.offset_y = new_positions.y - ppos.y

            @position.set new_positions

            return cancelEvent(event)
