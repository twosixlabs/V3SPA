
    Router = Backbone.Router.extend
        routes:
            'editor'                   : 'editor'
            'node'                     : 'node'
            'load/:example'            : 'load'
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
            $('#editor-container').toggle()

        load: (example) ->
            $.ajax
                url: "/static/data/#{example}.lsr.json"
                success: (lsr) ->
                    Parser.Load(lsr)

            return

        node: () ->
            #vespa.avispa.$nodes.append node.$el

            #@cleanse()
            #if not @editor
            #    @editor = new Editor
            #@modal.append(@editor.$el)

        logout: () ->
            window.location = '/logout'
