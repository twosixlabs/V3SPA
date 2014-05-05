
Base class for "link" objects

    #Link = Backbone.View.extend
    #    className: 'link'
    #    initialize: () ->

    Avispa.Link = Backbone.View.extend
        el: () -> $SVG('g').attr('class', 'link')

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

        initialize: (@options) ->
            @path = $SVG('path')
                .css('marker-end', 'url(#Arrow)')
                .css('opacity', '0.5')
                .appendTo(@$el)

            _.bindAll @,
                'render',
                'OnMouseDown', 'OnMouseEnter', 'OnMouseLeave', 'OnRightClick'

            @left  = @options.left
            @right = @options.right

            @arc = new GenericModel
                arc: 10

            @arc.bind 'change', @render, @

Bind to the position of the left and right sides of the connection

            @left.position.bind  'change', @render, @
            @right.position.bind 'change', @render, @

            @render()

            return @

        update: () ->
            #@label.text(name)
            return

        render: () ->
            return @ if not @arc

            arc = @arc.get('arc')
            lpos = @left.AbsPosition()
            rpos = @right.AbsPosition()

            # calculate the angle between 2 nodes
            ang = Math.atan2(rpos.x - lpos.x, rpos.y - lpos.y)

            # bound the offset to about half the circle
            offset = Math.max(-1.5, Math.min(1.5, arc / 100))

            # draw to the edge of the node
            lpos.x +=  30 * Math.sin(ang + offset)
            lpos.y +=  30 * Math.cos(ang + offset)
            rpos.x += -33 * Math.sin(ang - offset)
            rpos.y += -33 * Math.cos(ang - offset)

            # calculate the the position for the quadratic bezier curve
            xc = ((lpos.x + rpos.x) >> 1) + arc * Math.cos(ang)
            yc = ((lpos.y + rpos.y) >> 1) - arc * Math.sin(ang)

            mx = xc - (arc>>1) * Math.cos(ang)
            my = yc + (arc>>1) * Math.sin(ang)

            rot = -(RAD * ang)
            if rot > 0 and rot < 180
            then rot -= 90
            else rot += 90

            @path.attr('d', "M #{lpos.x} #{lpos.y} Q #{xc} #{yc} #{rpos.x} #{rpos.y}")
            #@label.attr('x', mx).attr('y', my).attr('transform', "rotate(#{rot}, #{mx} #{my})")

            return @

        # --------------------------------------------------------------------------
        # events
        #

        Drag: (event) ->

            [x,y] = context.Point(event)

            from = @left.AbsPosition()
            to = @right.AbsPosition()

            d = (to.x - from.x) * (y - from.y) - (to.y - from.y) * (x - from.x)

            if d
                d = Math.pow(Math.abs(d), 0.5) * if d > 0 then -1 else 1

            if not @od and @od isnt 0
                @od = d

            # will trigger a call to render
            @arc.set('arc', Math.max(10, @oarc + d - @od))

            return

        OnMouseDown: (event) ->
            @jitter = 0

            context.dragItem = @
            @oarc = @arc.get('arc')
            @od = null

            return cancelEvent(event)

        MouseUp: (event) ->
            if @jitter > 3
                @path.css('stroke-width', '3px')

            return

        OnMouseEnter: () ->
            if not context.dragItem?
                @path.css('stroke-width', '6px')
                @path.css('stroke-opacity', '0.8')

                context.ide_backend.highlight(@options.data)
            return

        OnMouseLeave: () ->
            if not context.dragItem?
                @path.css('stroke-width', '3px')
                @path.css('stroke-opacity', '0.5')
                context.ide_backend.unhighlight()
            return

        LeftClick: (event) ->
            @arc.set('arc', 0) if event.shiftKey
            return

        OnRightClick: (event) ->
            return cancelEvent(event)
