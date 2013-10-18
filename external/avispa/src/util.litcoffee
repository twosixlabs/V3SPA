
A wrapper function to create jQuery SVG elements

    window.$SVG ?= (name) -> $( document.createElementNS('http://www.w3.org/2000/svg', name) )

Allow jQuery to access the mouse scroll wheel data

    jQuery.event.props.push('wheelDelta')
    jQuery.event.props.push('detail')

Cancel an event

    window.cancelEvent ?= (event) ->
        event.preventDefault()
        event.stopPropagation()
        return false
