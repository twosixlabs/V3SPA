
    Router = Backbone.Router.extend
        routes:
            'plugin/:plugin(/*action)' : 'plugin'
            'editor'                   : 'editor'
            'logout'                   : 'logout'
            ''                         : 'main'

        initialize: () ->
            @modal = $('#modal')
            @editor = null
            return

        cleanse: () ->
            #$(document).off '.module'
            @modal.empty()

        main: () ->
            console.log('main')
            @cleanse()

        editor: () ->
            console.log('editor')
            @cleanse()
            if not @editor
                @editor = new Editor
            @modal.append(@editor.$el)

        logout: () ->
            window.location = '/logout'