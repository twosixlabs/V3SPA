
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

            pos = @AbsPosition()
            @$rect
                .attr('x', pos.x)
                .attr('y', pos.y)
            return @

        OnMouseEnter: (event) ->
            if Avispa.context.hovering? and @options._id != Avispa.context.hovering.options._id
              if not context.dragItem?
                  Avispa.context.hovering.$rect.removeAttr('class')
                  Avispa.context.ide_backend.unhighlight()

            Avispa.context.hovering = @

            if not Avispa.context.dragItem?
                @$rect.attr('class', 'hover')

                Avispa.context.ide_backend.highlight(@options.data)

            return #cancelEvent(event)

        OnMouseLeave: (event) ->
            if not Avispa.context.dragItem?
                @$rect.removeAttr('class')
                Avispa.context.ide_backend.unhighlight()
            return cancelEvent(event)

        Drag: (event) ->
            new_positions =
              x: (event.clientX / Avispa.context.scale) - @clickOffsetX
              y: (event.clientY / Avispa.context.scale) - @clickOffsetY

            @position.set @EnforceBoundingBox(new_positions)

            for child in @children
              do (child)->
                child.ParentDrag()

            return cancelEvent(event)
