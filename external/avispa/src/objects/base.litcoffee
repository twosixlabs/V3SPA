
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
                @parent.position.bind 'change', @ParentDrag, @

Allow a list of classes to be passed in.

            if @options.klasses
              classes = _.toArray @.el.classList
              classes =_.union classes, @options.klasses

              @.$el.attr 'class', classes.join ' '

            @position = new GenericModel(@options.position, @options._id)
            @position.bind 'change', @render, @

The init method allows classes to extend the BaseObject without re-implementing this initialize function

            @_init()
            @init?()

            @render()
            return @

        AbsPosition: ->
          #if @position.get('x') and @position.get('y')
          #    ret = 
          #      x: @position.get('x')
          #      y: @position.get('y') 
          #
          #    return ret

          if @parent
              ppos = @parent.AbsPosition()
              ret =
                x: @position.get('offset_x') + ppos.x
                y: @position.get('offset_y') + ppos.y
          else
              ret =
                x: @position.get('offset_x')
                y: @position.get('offset_y') 

          @position.set ret
          return ret


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

        EnforceBoundingBox: (coords)->

If we have a parent element, we want to make sure that our box is at least
10 pixels inside of it at all times. We start by calculating the amount of
space space there is around the edges of this group.

            shift_x = coords.x - @position.get('x')
            shift_y = coords.y - @position.get('y')
            offset_x = @position.get('offset_x') + shift_x
            offset_y = @position.get('offset_y') + shift_y

            if @parent
                ppos = 
                  x: @parent.position.get('x')
                  y: @parent.position.get('y')
                  w: @parent.position.get('w')
                  h: @parent.position.get('h')


                if offset_x < 10
                    offset_x = 10
                else if offset_x + @position.get('w') > ppos.w - 10
                    offset_x = ppos.w - 10 - @position.get('w')

                if offset_y < 10
                    offset_y = 10
                else if offset_y + @position.get('h') > ppos.h - 10
                    offset_y = ppos.h - 10 - @position.get('h')

            ret = 
              offset_x: offset_x
              offset_y: offset_y

            @position.set ret

        Drag: (event) ->
            new_positions = 
                x: (event.clientX / context.scale) - @x1
                y: (event.clientY / context.scale) - @y1

            @EnforceBoundingBox new_positions

            return cancelEvent(event)
