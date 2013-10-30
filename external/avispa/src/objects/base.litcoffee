
The Avispa.BaseObject represents an abstract base class for Group and Node
elements.  The root is an SVG G element that is translated when dragged.

    Avispa.BaseObject = Backbone.View.extend

        events:
            'mousedown'   : 'OnMouseDown'
            'mouseenter'  : 'OnMouseEnter'
            'mouseleave'  : 'OnMouseLeave'
            'contextmenu' : 'OnRightClick'

The "Position" model is defined by the project that is importing Avispa.

        initialize: (@options) ->
            _.bindAll @, 'OnMouseDown'

            @parent = @options.parent if @options
            @parent.$el.append(@$el) if @parent

            @position = new Models.Position
                x: 0
                y: 0
            @position.bind 'change', @render, @

            @init()

        render: () ->
            @$el.attr('transform', "translate(#{@position.get('x')}, #{@position.get('y')})")

        OnMouseDown: (event) ->
            @x1 = (event.clientX / context.scale) - @position.get('x')
            @y1 = (event.clientY / context.scale) - @position.get('y')

            # TODO: calculate the bounds of the parent element

            context.dragItem = @

            return cancelEvent(event)

        Drag: (event) ->
            x = (event.clientX / context.scale) - @x1
            y = (event.clientY / context.scale) - @y1

            @position.set 'x': x, 'y': y

            return cancelEvent(event)
