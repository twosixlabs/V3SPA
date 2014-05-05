
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

            @children = []

            @cache_hit = 0
            @cache_miss = 0

Expect a position to be passed in

            @parent  = @options.parent
            position = @options.position

If we have a parent, keep track of our offset from the parent

            if @parent
                @parent.children.push @

Allow a list of classes to be passed in.

            if @options.klasses
              classes = _.toArray @.el.classList
              classes =_.union classes, @options.klasses

              @.$el.attr 'class', classes.join ' '

            @position = new GenericModel(@options.position, @options._id)
            @position.bind 'change', @render, @

            @position_cache = {}

The init method allows classes to extend the BaseObject without re-implementing this initialize function

            @_init()
            @init?()

            @render()
            return @

        AbsPosition: (expected)->

          if @parent
              if not @ppos_cached?
                @cache_miss++
                @ppos_cached = @parent.AbsPosition()
              else
                @cache_hit++

              ret =
                x: @position.get('offset_x') + @ppos_cached.x
                y: @position.get('offset_y') + @ppos_cached.y
          else
              ret =
                x: @position.get('offset_x')
                y: @position.get('offset_y')

          return ret

        width: ->
          return @position.get('w')

        height: ->
          return @position.get('h')

        ParentDrag: (ppos) ->

            @ppos_cached = null
            @render()
            for child in @children
              do (child)->
                child.ParentDrag()

        OnMouseDown: (event) ->
            @jitter = 0

            pos = @AbsPosition()

            @clickOffsetX = (event.clientX / context.scale) - pos.x
            @clickOffsetY = (event.clientY / context.scale) - pos.y

            context.dragItem = @

            return cancelEvent(event)

        EnforceBoundingBox: (coords)->

If we have a parent element, we want to make sure that our box is at least
10 pixels inside of it at all times. We start by calculating the amount of
space space there is around the edges of this group.

            currpos = @AbsPosition()

            shift_x = coords.x - currpos.x
            shift_y = coords.y - currpos.y
            offset_x = @position.get('offset_x') + shift_x
            offset_y = @position.get('offset_y') + shift_y

            if @parent
                ppos_abs = @parent.AbsPosition()
                ppos =
                  x: ppos_abs.x
                  y: ppos_abs.y
                  w: @parent.width()
                  h: @parent.height()

                if offset_x < 10
                    offset_x = 10
                else if offset_x + @width() > ppos.w - 10
                    offset_x = ppos.w - 10 - @width()

                if offset_y < 10
                    offset_y = 10
                else if offset_y + @height() > ppos.h - 10
                    offset_y = ppos.h - 10 - @height()

            console.log("#{@options._id}: #{@cache_hit} hits, #{@cache_miss} misses")

            ret =
              offset_x: offset_x
              offset_y: offset_y

        Drag: (event) ->
            new_positions =
                x: (event.clientX / context.scale) - @x1
                y: (event.clientY / context.scale) - @y1

            @position.set @EnforceBoundingBox(new_positions)

            return cancelEvent(event)
