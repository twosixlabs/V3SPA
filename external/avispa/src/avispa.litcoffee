
    zoom =
        step : 0.125
        min  : 0.125
        max  : 2.5

    window.Avispa = Backbone.View.extend
        className: 'AvispaView'

        events:
            'mousedown.avispa      SVG' : 'OnMouseDown'
            'mousemove.avispa      SVG' : 'OnMouseMove'
            'mouseup.avispa        SVG' : 'OnMouseUp'
            'mousewheel.avispa     SVG' : 'OnMouseWheel'
            'DOMMouseScroll.avispa SVG' : 'OnMouseWheel'
            'contextmenu.avispa    SVG' : 'OnContextMenu'

        # for child class initialization
        secondstage: () ->

        initialize: () ->
            _.bindAll @, 'render',
                'OnMouseDown', 'OnMouseMove', 'OnMouseUp', 'OnMouseWheel', 'OnContextMenu'

            window.riskview = @

            @scale    = 1.0
            @links    = {}
            @offset   = null
            @dragItem = null
            @arrow    = null

            @$el.html($('#template_risk').text())

            # find the SVG element from the template
            @$canvas = @$('svg.avispa')
            @canvasdom = @$canvas.get(0)
            @$parent = @$canvas.parent()

            @$pan    = @$canvas.find('g.pan')
            @$zoom   = @$canvas.find('g.zoom')

            @$links  = @$canvas.find('g.links')
            @$nodes  = @$canvas.find('g.nodes')
            @$labels = @$canvas.find('g.labels')

            @$pan.x = window.innerWidth / 2
            @$pan.y = window.innerHeight / 2

            @Pan(0,0)

            @$('#zoomslider')
                .slider
                    value: 1.0
                    min:   zoom.min
                    max:   zoom.max
                    step:  zoom.step
                    slide: (event, ui) ->
                        riskview.Scale(ui.value)

                .on 'mousedown', (event) ->
                    # zoom to normal on non-left click of zoom control
                    #cancelEvent(event)
                    if event.which != 1
                        riskview.Scale(1.0)
                        $(@).slider('value', 1.0)
                    event.stopPropagation()
                    return

                .on 'mousewheel', (event) ->
                    # zoom in and out when scrolling the wheel
                    d = normalizeWheel(event)

                    z = Math.max(0.25, Math.min(3.0, $(@).slider('value') + d * 0.25))
                    riskview.Scale(z)
                    $(@).slider('value', z)
                    return cancelEvent(event)

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
            else scale = @scale + delta * zoom.step

            return @ if scale <= zoom.min or scale >= zoom.max

            @Scale(scale)
            return @

        Point: (event) ->
            # translates the client x,y into the canvas x,y
            point = @canvasdom.createSVGPoint()
            point.x = event.clientX
            point.y = event.clientY
            point = point.matrixTransform(@canvasdom.getScreenCTM().inverse())

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
                @dragItem.jitter++
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
            #@MouseWheel(event) if @MouseWheel?
            #if event.shiftKey
            @Zoom(normalizeWheel(event))
            @$('#zoomslider').slider('option', 'value', @scale)
            return cancelEvent(event)

        OnContextMenu: (event) ->
            return cancelEvent(event)


