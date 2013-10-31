
    context = null

Expose a global view class so that consumers of the API can instantiate a view.

    window.Avispa = Backbone.View.extend

        events:
            'mousedown.avispa'      : 'OnMouseDown'
            'mousemove.avispa'      : 'OnMouseMove'
            'mouseup.avispa'        : 'OnMouseUp'
            'mousewheel.avispa'     : 'OnMouseWheel'
            'DOMMouseScroll.avispa' : 'OnMouseWheel'
            'contextmenu.avispa'    : 'OnContextMenu'

        # for child class initialization
        secondstage: () ->

        initialize: (options) ->
            context = @

            _.bindAll @, 'render',
                'OnMouseDown', 'OnMouseMove', 'OnMouseUp', 'OnMouseWheel', 'OnContextMenu'

            @scale    = 1.0
            @links    = {}
            @offset   = null
            @dragItem = null
            @arrow    = null

            @position = new Models.Position
                x: 0
                y: 0

            @zoom =
                step : 0.125
                min  : 0.125
                max  : 2.5

            @$parent  = @$el.parent()

            @$pan     = @$el.find('g.pan')
            @$zoom    = @$el.find('g.zoom')

            @$links   = @$el.find('g.links')
            @$objects = @$el.find('g.objects')
            @$labels  = @$el.find('g.labels')

            @$pan.x = window.innerWidth  / 2
            @$pan.y = window.innerHeight / 2

            @Pan(0,0)

            @secondstage()

            return @

        Pan: (dx, dy) ->
            @$pan.x += dx
            @$pan.y += dy

            @$pan.attr('transform', "translate(#{@$pan.x}, #{@$pan.y})")
            @$parent.css('background-position', "#{@$pan.x}px #{@$pan.y}px")
            return @

        Scale: (@scale) ->
            @$zoom.attr('transform', "scale(#{scale})")
            return @

        Zoom: (delta) ->
            if delta is 0 then scale = 1.0
            else scale = @scale + delta * @zoom.step

            return @ if scale <= @zoom.min or scale >= @zoom.max

            @Scale(scale)
            return @

        Point: (event) ->
            # translates the client x,y into the surface x,y
            point = @el.createSVGPoint()
            point.x = event.clientX
            point.y = event.clientY
            point = point.matrixTransform(@el.getScreenCTM().inverse())

            # account for the current pan and scale
            point.x = parseInt((point.x - @$pan.x) / @scale)
            point.y = parseInt((point.y - @$pan.y) / @scale)

            return [point.x, point.y]

        OnMouseDown: (event) ->
            if @arrow?
                @arrow.Remove()
                @arrow = null
                return cancelEvent(event)

            switch event.which
                when 1 then @LeftDown(event)
                when 2 then @MiddleDown(event)
                when 3 then @RightDown(event) if @RightDown

            return cancelEvent(event)

        LeftDown: (event) ->
            #if event.shiftKey
            @offset = [event.clientX, event.clientY]
            return

        MiddleDown: (event) ->
            @Pan(-@$pan.x + window.innerWidth / 2, -@$pan.y + window.innerHeight / 2)
            @Zoom(0)
            @$('#zoomslider').slider('option', 'value', 1)
            return

        OnMouseMove: (event) ->
            # drag the entire scene around
            if @offset
                @Pan(event.clientX - @offset[0], event.clientY - @offset[1])
                @offset = [event.clientX, event.clientY]

            else if @arrow
                @arrow.Drag(event)

            else if @dragItem
                #@dragItem.jitter++
                @dragItem.Drag(event) if @dragItem.Drag

            return cancelEvent(event)

        OnMouseUp: (event) ->
            @offset = null

            if @dragItem?
                if @dragItem.jitter < 3
                    switch event.which
                        when 1 then @dragItem.LeftClick(event)   if @dragItem.LeftClick
                        when 2 then @dragItem.MiddleClick(event) if @dragItem.MiddleClick
                        when 3 then @dragItem.RightClick(event)  if @dragItem.RightClick

                @dragItem.MouseUp(event) if @dragItem?.MouseUp
                @dragItem = null

            else
                switch event.which
                    when 1 then @LeftClick(event)   if @LeftClick
                    when 2 then @MiddleClick(event) if @MiddleClick
                    when 3 then @RightClick(event)  if @RightClick

            return cancelEvent(event)

        OnMouseWheel: (event) ->
            @Zoom(normalizeWheel(event))
            @$('#zoomslider').slider('option', 'value', @scale)
            return cancelEvent(event)

        OnContextMenu: (event) ->
            console.log('yeah')
            return cancelEvent(event)


