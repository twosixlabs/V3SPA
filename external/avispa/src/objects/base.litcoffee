
The Avispa.BaseObject represents an abstract base class for Group and Node
elements.  The root is an SVG G element that is translated when dragged.

    Avispa.BaseObject = Backbone.View.extend

        events:
            'mousedown'   : 'OnMouseDown'
            'mouseenter'  : 'OnMouseEnter'
            'mouseleave'  : 'OnMouseLeave'
            'contextmenu' : 'OnRightClick'

        highlight: ->
          classes = _.toArray @.el.classList
          classes.push 'svg-highlight'
          @.$el.attr 'class', _.uniq(classes).join(" ")

        unhighlight: ->
          classes = _.reject @.el.classList, (klass)->
            klass == 'svg-highlight'
          @.$el.attr 'class', classes.join(" ")

The "Position" model is defined by the project that is importing Avispa.

        initialize: (@options) ->
            _.bindAll @, 'OnMouseDown'

            @highlighted = false

Expect a position to be passed in

            @parent  = @options.parent
            position = @options.position

If we have a parent, keep track of our offset from the parent

            if @parent
                position.offset_x = position.x
                position.offset_y = position.x

                position.x += @parent.position.get('x')
                position.y += @parent.position.get('y')

                @parent.position.bind 'change', @ParentDrag, @

            else
              position = @options.position

            @position = new GenericModel(position, @options._id)
            @position.bind 'change', @render, @

The init method allows classes to extend the BaseObject without re-implementing this initialize function

            @_init()
            @init?()

            @render()
            return @

        ParentDrag: (ppos) ->
            @position.set
                x: @position.get('offset_x') + ppos.get('x')
                y: @position.get('offset_y') + ppos.get('y')
            return

        OnMouseDown: (event) ->
            @jitter = 0

            @clickOffsetX = (event.clientX / context.scale) - @position.get('x')
            @clickOffsetY = (event.clientY / context.scale) - @position.get('y') 

            context.dragItem = @

            return cancelEvent(event)

        Drag: (event) ->
            x = (event.clientX / context.scale) - @x1
            y = (event.clientY / context.scale) - @y1

            @position.set 'x': x, 'y': y

            return cancelEvent(event)
