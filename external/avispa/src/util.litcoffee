
A wrapper function to create jQuery SVG elements

    window.$SVG ?= (e) -> $( document.createElementNS('http://www.w3.org/2000/svg', e) )

Allow jQuery to access the mouse scroll wheel data

    jQuery.event.props.push('wheelDelta')
    jQuery.event.props.push('detail')
