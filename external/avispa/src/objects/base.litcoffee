
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

Allow a list of classes to be passed in.

            if @options.klasses
              classes = _.toArray @.el.classList
              classes =_.union classes, @options.klasses

              @.$el.attr 'class', classes.join ' '

            @position = new GenericModel(position, @options._id)
            @position.bind 'change', @render, @

The init method allows classes to extend the BaseObject without re-implementing this initialize function

            @_init()
            @init?()

            @render()
            return @

        ParentDrag: (ppos) ->
            offset_pos = 
                x: @position.get('offset_x') + ppos.get('x')
                y: @position.get('offset_y') + ppos.get('y')

            @EnforceBoundingBox offset_pos

            return

        OnMouseDown: (event) ->
            @jitter = 0

            @clickOffsetX = (event.clientX / context.scale) - @position.get('x')
            @clickOffsetY = (event.clientY / context.scale) - @position.get('y') 

            context.dragItem = @

            return cancelEvent(event)

        EnforceBoundingBox: (coords)->

If we have a parent element, we want to make sure that our box is at least
10 pixels inside of it at all times. We start by calculating the amount of
space space there is around the edges of this group.

            if @parent
                ppos = 
                  x: @parent.position.get('x')
                  y: @parent.position.get('y')
                  w: @parent.position.get('w')
                  h: @parent.position.get('h')

                limit = 
                  left: ppos.x + 10
                  right: (ppos.x + ppos.w) - 10
                  beginning: ppos.y + 10
                  end: ppos.y + ppos.h - 10

                if coords.x < limit.left
                    coords.x = limit.left
                else if coords.x + @position.get('w') > limit.right
                    coords.x = limit.right - @position.get('w')

                if coords.y < limit.beginning
                    coords.y = limit.beginning
                else if coords.y + @position.get('h') > limit.end
                    coords.y = limit.end - @position.get('h')

                coords.offset_x = coords.x - ppos.x
                coords.offset_y = coords.y - ppos.y

            @position.set coords

        Drag: (event) ->
            x = (event.clientX / context.scale) - @x1
            y = (event.clientY / context.scale) - @y1

            @position.set 'x': x, 'y': y

            return cancelEvent(event)
