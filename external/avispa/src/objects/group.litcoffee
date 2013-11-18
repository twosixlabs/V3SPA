
Base class for "group" objects

    Avispa.Group = Avispa.BaseObject.extend
        el: () -> $SVG('g').attr('class', 'group')

        _init: () ->
            @$rect = $SVG('rect')
                .attr('width',  @position.get('w'))
                .attr('height', @position.get('h'))
                .css('fill', @position.get('fill'))
                .appendTo(@$el)

            return

        render: () ->
            #@$el.attr('transform', "translate(#{@position.get('x')}, #{@position.get('y')})")
            @$rect
                .attr('x', @position.get('x'))
                .attr('y', @position.get('y'))
            return @
