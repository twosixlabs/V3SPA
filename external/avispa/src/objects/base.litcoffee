
    Avispa.BaseObject = Backbone.View.extend

        events:
            'mousedown'   : 'OnMouseDown'
            'mouseenter'  : 'OnMouseEnter'
            'mouseleave'  : 'OnMouseLeave'
            'contextmenu' : 'OnRightClick'

        initialize: (@options) ->
            _.bindAll @, 'OnMouseDown'

            @parent = @options
            @position = new Models.Position
                x: 0
                y: 0
            @position.bind 'change', @render, @
            @options?.parent?.$el.append(@$el)

            @init()

        render: () ->
            @$el.attr('transform', "translate(#{@position.get('x')}, #{@position.get('y')})")

        OnMouseDown: (event) ->
            @x1 = (event.clientX / context.scale) - @position.get('x')
            @y1 = (event.clientY / context.scale) - @position.get('y')

            context.dragItem = @

            return cancelEvent(event)

        Drag: (event) ->
            x = (event.clientX / context.scale) - @x1
            y = (event.clientY / context.scale) - @y1

            @position.set 'x': x, 'y': y

            return cancelEvent(event)
