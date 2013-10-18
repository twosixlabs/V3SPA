
Zoom slider

    @$('#zoomslider')
        .slider
            value: 1.0
            min:   zoom.min
            max:   zoom.max
            step:  zoom.step
            slide: (event, ui) ->
                #riskview.Scale(ui.value)

        .on 'mousedown', (event) ->
            # zoom to normal on non-left click of zoom control
            #cancelEvent(event)
            if event.which != 1
                #riskview.Scale(1.0)
                $(@).slider('value', 1.0)
            event.stopPropagation()
            return

        .on 'mousewheel', (event) ->
            # zoom in and out when scrolling the wheel
            d = normalizeWheel(event)

            z = Math.max(0.25, Math.min(3.0, $(@).slider('value') + d * 0.25))
            #riskview.Scale(z)
            $(@).slider('value', z)
            return cancelEvent(event)

