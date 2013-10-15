
This is the Lobster editor view.

    Editor = Backbone.View.extend
        id: "editor"

        initialize: () ->
            @$el.append $(_.template(templates.editor)())
            return @
