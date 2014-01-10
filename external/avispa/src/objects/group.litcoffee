
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
            x = (event.clientX / context.scale) - @x1
            y = (event.clientY / context.scale) - @y1

            if @offset
                @offset.x = @ox1 + x
                @offset.y = @oy1 + y

                boundsx = @parent.position.get('w') - @position.get('w') - 10
                boundsy = @parent.position.get('h') - @position.get('h') - 10

                if @offset.x < 10
                    @offset.x = 10
                    x = @parent.position.get('x') + 10
                else if @offset.x > boundsx
                    @offset.x = boundsx
                    x = @parent.position.get('x') + boundsx
                if @offset.y < 10
                    @offset.y = 10
                    y = @parent.position.get('y') + 10
                else if @offset.y > boundsy
                    @offset.y = boundsy
                    y = @parent.position.get('y') + boundsy

            @position.set 'x': x, 'y': y

            return cancelEvent(event)
