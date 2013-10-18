
    Avispa.BaseObject = Backbone.View.extend

        events:
            'mousedown'   : 'OnMouseDown'
            'mouseenter'  : 'OnMouseEnter'
            'mouseleave'  : 'OnMouseLeave'
            'contextmenu' : 'OnRightClick'

        OnMouseDown: () ->
            context.dragItem = @
            console.log(context.dragItem)
            return cancelEvent(event)

        Drag: (event) ->
            #x = @position.get('x')
            #y = @position.get('y')

            x += (event.clientX / context.scale) - @old_x - x
            y += (event.clientY / context.scale) - @old_y - y

            @position.set 'x': x, 'y': y

            #msg = _.extend
            #    action: 'UpdatePosition'
            #  ,
            #    @position.toJSON()
            #controller.ws.send(JSON.stringify(msg))

            return
