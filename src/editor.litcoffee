
This is the Lobster editor view.

    Editor = Backbone.View.extend
        id:        'editor'
        className: 'dialog'

        initialize: () ->
            @$el.html '<textarea resizable="0"></textarea>'
            #@$el.html $('<p>hey girl</p>')

            @$el.attr('title', 'hey')

            @$el.dialog
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

            console.log(@$el)

            return @
