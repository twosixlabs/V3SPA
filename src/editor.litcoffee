
This is the Lobster editor view.

    Editor = Backbone.View.extend
        id:        'editor'
        className: 'dialog'

        initialize: () ->
            @$el
                .attr('title', 'Editor')
                .html('<textarea resizable="0"></textarea>')
                .dialog
                    resizable : true
                    width     : 400
                    minWidth  : 400
                    height    : 400
                    minHeight : 400
                    modal     : false
                    hide:
                        effect: 'fade'
                        duration: 200
                    buttons:
                        'Update': () ->
                            $(@).dialog( "close" )
                        'Cancel': () ->
                            $(@).dialog( "close" )

            return @
