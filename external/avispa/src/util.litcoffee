
A wrapper function to create jQuery SVG elements

    window.$SVG ?= (name) -> $( document.createElementNS('http://www.w3.org/2000/svg', name) )

Cancel an event

    window.cancelEvent ?= (event) ->
        event.preventDefault()
        event.stopPropagation()
        return false

Standardize the way scrolling the mousewheel is handled across browsers

    jQuery.event.props.push('wheelDelta')
    jQuery.event.props.push('detail')

    window.normalizeWheel ?= (event) ->
        return event.wheelDelta / 120 if event.wheelDelta
        return event.detail     /  -3 if event.detail
        return 0

Constants

    RAD = 180.0 / Math.PI
