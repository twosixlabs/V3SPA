
The Avispa.BaseObject represents an abstract base class for Group and Node
elements.  The root is an SVG G element that is translated when dragged.

    Avispa.BaseObject = Backbone.View.extend

        events:
            'mousedown'   : 'OnMouseDown'
            'mouseenter'  : 'OnMouseEnter'
            'mouseleave'  : 'OnMouseLeave'
            'contextmenu' : 'OnRightClick'
            'mousewheel'     : 'OnMouseWheel'
            'DOMMouseScroll' : 'OnMouseWheel'

        add_class: (klass)->
          classes = _.toArray @.el.classList
          classes.push klass
          @.$el.attr 'class', _.uniq(classes).join(" ")

        remove_class: (klass)->
          classes = _.toArray @.el.classList
          console.log classes
          classes = _.reject classes, (cls)->
            cls == klass
          console.log classes
          @.$el.attr 'class', classes.join(" ")

        highlight: ->
          @add_class('svg-highlight')

        unhighlight: ->
          @remove_class('svg-highlight')

The "Position" model is defined by the project that is importing Avispa.

        initialize: (@options) ->
            _.bindAll @, 'OnMouseDown'

            @highlighted = false

            @children = []

            @cache_hit = 0
            @cache_miss = 0

Expect a position to be passed in. The position object should respond
to 'bind', 'set' and 'get'.

            @parent  = @options.parent
            if @options.position
              @position = @options.position
              @position.bind 'change', @render, @

If we have a parent, keep track of our offset from the parent

            if @parent
                @parent.children.push @

Allow a list of classes to be passed in.

            if @options.klasses
              classes = _.toArray @.el.classList
              classes =_.union classes, @options.klasses

              @.$el.attr 'class', classes.join ' '


The init method allows classes to extend the BaseObject without re-implementing this initialize function

            @_init?()
            @init?()

            return @

        AncestorList: ->

          if @parent
            list = @parent.AncestorList()
            list.push @options.data.name
            return list
          else if @options.fake_container
            return []
          else
            return [@options.data.name]


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
            pos = @AbsPosition()
            pos = _.extend pos, @EnforceBoundingBox(pos)
            @position.set pos
            @render()

            for child in @children
              do (child)->
                child.ParentDrag()

        OnMouseDown: (event) ->
            @jitter = 0

            pos = @AbsPosition()

            @clickOffsetX = (event.clientX / Avispa.context.scale) - pos.x
            @clickOffsetY = (event.clientY / Avispa.context.scale) - pos.y

            Avispa.context.dragItem = @

            return cancelEvent(event)

        QuadTreeFactory: d3.geom.quadtree().x( (d)->
                  d.position.get('offset_x') + d.width() / 2
              ).y( (d)->
                  d.position.get('offset_y') + d.height() / 2
              )

Get the quadtree corresponding to the child nodes of this node, except
for the provided child

        QuadTree: (exclude)->
          nodes = _.reject @children, (child)-> 
            child.options._id == exclude.options._id
          qtree = @QuadTreeFactory(nodes)

Return the bounds of this object

        LocalBounds: (x, y)->
          ret = 
            x1 : x
            x2 : x + @width()
            y1 : y
            y2 : y + @height()

        EnforceBoundingBox: (coords)->

If we have a parent element, we want to make sure that our box is at least
10 pixels inside of it at all times. We start by calculating the amount of
space space there is around the edges of this group.

            currpos = @AbsPosition()
            width =  @width()
            height =  @height()

            shift_x = coords.x - currpos.x
            shift_y = coords.y - currpos.y
            prev = 
              x : @position.get('offset_x')
              y : @position.get('offset_y')

            offset=
              x : @position.get('offset_x') + shift_x
              y : @position.get('offset_y') + shift_y

            if @parent

We build a qtree containing all the parents children except this one.
We traverse the quadtree, and make sure that this movement won't
move us into the bounding box of the peer

                qtree = @parent.QuadTree(@)
                qtree.visit (quad, x1, y1, x2, y2)=>
                  return unless quad.point?
                  n = @LocalBounds(offset.x, offset.y)

                  quad_bounds = quad.point.LocalBounds(
                    quad.point.position.get('offset_x'),
                    quad.point.position.get('offset_y'))

                  x_overlap = y_overlap = false
                  if ((n.x1 < quad_bounds.x2 and n.x2 > quad_bounds.x2))
                    x_overlap = Math.abs(n.x1 - quad_bounds.x2)
                  else if (n.x2 > quad_bounds.x1 and n.x1 < quad_bounds.x1)
                    x_overlap = Math.abs n.x2 - quad_bounds.x1
                  else if n.x1 >= quad_bounds.x1 and n.x2 <= quad_bounds.x2
                    x_overlap = Math.min(
                      Math.abs(n.x2 - quad_bounds.x1),
                      Math.abs(n.x1 - quad_bounds.x2)
                    )

                  if ((n.y1 < quad_bounds.y2 and n.y2 > quad_bounds.y2))
                    y_overlap = Math.abs n.y1 - quad_bounds.y2
                  else if (n.y2 > quad_bounds.y1 and n.y1 < quad_bounds.y1)
                    y_overlap = Math.abs n.y2 - quad_bounds.y1
                  else if n.y1 >= quad_bounds.y1 and n.y2 <= quad_bounds.y2
                    y_overlap = Math.min(
                      Math.abs(n.y2 - quad_bounds.y1),
                      Math.abs(n.y1 - quad_bounds.y2)
                    )

                  #console.log "xOver: #{x_overlap}, yOver: #{y_overlap}"

                  if x_overlap and y_overlap
                    if shift_x == 0 and shift_y == 0
                      # We're not moving, so they're just on top of eachother
                      _.sample([
                        ->(offset.x = quad_bounds.x1 - width),
                        ->(offset.x = quad_bounds.x2),
                        ->(offset.y = quad_bounds.y1 - height),
                        ->(offset.y = quad_bounds.y2)
                      ])()

                    else if x_overlap < y_overlap
                      if shift_x > 0
                        offset.x = quad_bounds.x1 - width
                      else if shift_x < 0
                        offset.x = quad_bounds.x2

                    else
                      if shift_y < 0
                        offset.y = quad_bounds.y2
                      else if shift_y > 0
                        offset.y = quad_bounds.y1 - height

                  return x_overlap and y_overlap

                unless @parent.options.fake_container
                  ppos_abs = @parent.AbsPosition()
                  ppos =
                    x: ppos_abs.x
                    y: ppos_abs.y
                    w: @parent.width()
                    h: @parent.height()

                  offset.x = @EnforceXOffset(offset.x, ppos.w)
                  offset.y = @EnforceYOffset(offset.y, ppos.h)

            ret =
              offset_x: offset.x
              offset_y: offset.y

        EnforceXOffset: (offset, pwidth)->
            orig_offset = offset
            if offset < 10
                offset = 10
            else if offset + @width() > pwidth - 10
                offset = pwidth - 10 - @width()

            if offset < 10
              offset = orig_offset

            return offset

        EnforceYOffset: (offset, height)->
            orig_offset = offset

            if offset < 25
                offset = 25
            else if offset + @height() > height - 10
                offset = height - 10 - @height()

            if offset < 10
              offset = orig_offset
            return offset

        Drag: (event) ->
            new_positions =
                x: (event.clientX / Avispa.context.scale) - @x1
                y: (event.clientY / Avispa.context.scale) - @y1

            @position.set @EnforceBoundingBox(new_positions)

            return cancelEvent(event)
