
    Router = Backbone.Router.extend
        routes:
            'editor'                   : 'editor'
            'node'                     : 'node'
            'logout'                   : 'logout'
            ''                         : 'main'

        initialize: () ->
            @modal = $('#modal')
            @editor = null
            return

        cleanse: () ->
            #$(document).off '.module'
            #@modal.empty()

        main: () ->
            @cleanse()

        editor: () ->
            @cleanse()
            if not @editor
                @editor = new Editor
            #@modal.append(@editor.$el)

        node: () ->
            group = new Avispa.Group
            vespa.avispa.$nodes.append group.$el

            node = new Avispa.Node
                parent: group

            node = new Avispa.Node
                parent: group

            group = new Avispa.Group
            vespa.avispa.$nodes.append group.$el

            node = new Avispa.Node
                parent: group

            node = new Avispa.Node
                parent: group

            #vespa.avispa.$nodes.append node.$el

            #@cleanse()
            #if not @editor
            #    @editor = new Editor
            #@modal.append(@editor.$el)

        logout: () ->
            window.location = '/logout'