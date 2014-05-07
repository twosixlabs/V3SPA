
    context = null

Expose a global view class so that consumers of the API can instantiate a view.

    window.Avispa = Backbone.View.extend

        events:
            'mousedown.avispa'      : 'OnMouseDown'
            'mousemove.avispa'      : 'OnMouseMove'
            'mouseup.avispa'        : 'OnMouseUp'
            'mouseleave.avispa'     : 'OnMouseUp'
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

            @OnMouseMove = _.throttle @OnMouseMove, 20

This loads the IDEBackend service into the context, so that any
of the Avispa code can access it.

            injector = angular.element('body').injector()
            IDEBackend = injector.get('IDEBackend')
            context.ide_backend = IDEBackend

If we have svgPanZoom, use it to pan and zoom around.

            if svgPanZoom?
              @have_svg_pan_zoom = true

Only actually initialize the context scroller if there is a
policy loaded. Otherwise we'll load the 'null' position for
no reason.

              svg_pan_opts =
                selector: '#surface svg'
                panEnabled: true
                zoomEnabled: true
                dragEnabled: false
                minZoom: 0.1
                maxZoom: 10

              if options.position?
                svg_pan_opts.onZoom = (scale, transform)->
                  context.scale = scale
                  options.position.update transform

                svg_pan_opts.onPanComplete = (coords, transform) ->
                  options.position.update transform

                svgPanZoom.init svg_pan_opts

                options.position.bind 'change', ->
                  g = svgPanZoom.getSVGViewport($("#surface svg")[0])
                  context.scale = options.position.data.a
                  svgPanZoom.set_transform(g, options.position.data)

                options.position.notify 'change'

              else
                svgPanZoom.init svg_pan_opts

If there is no svgPanZoom, then use the one Matt put together

            else
              @zoom =
                  step : 0.125
                  min  : 0.125
                  max  : 2.5
              @$pan     = @$el.find('g.pan')
              @$zoom    = @$el.find('g.zoom')

              @$pan.x = window.innerWidth  / 2
              @$pan.y = window.innerHeight / 2

              @Pan(0,0)

            @$parent  = @$el.parent()

            @$groups  = @$el.find('g.groups')
            @$links   = @$el.find('g.links')
            @$objects = @$el.find('g.objects')
            @$labels  = @$el.find('g.labels')



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

        OnMouseMove: (event)->
            # drag the entire scene around
            if @offset and not @have_svg_pan_zoom
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
            if not @have_svg_pan_zoom
              @Zoom(normalizeWheel(event))
              @$('#zoomslider').slider('option', 'value', @scale)
            return cancelEvent(event)

        OnContextMenu: (event) ->

    #= include util.litcoffee
    #= require templates.litcoffee
    #= require objects/base.litcoffee
    #= require objects/node.litcoffee
    #= require objects/link.litcoffee
    #= require objects/group.litcoffee

