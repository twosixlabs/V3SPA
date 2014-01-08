
    Views   = {}
    Dialogs = {}

    objects = {}

    models    = {}
    views     = {}
    templates = {}

    vespa = null

    editor = null

    #DT.Views.Plugins['controller'] = Backbone.View.extend
    #    initialize: () ->
    #        controller ?= new Controller()
    #        @$el = views.graph.$el
    #        return

This is the entry point into the V3SPA framework.

    $(document).ready () ->
        flip = true
        $('#expand').on 'click', () ->
            $('#status_pane').animate
                height: if flip then "+=8em" else "-=8em"
              ,
                200
              ,
                () ->
                    flip = !flip

        templates =
            editor: $( '#tmpl_editor' ).text()

        vespa ?= new Vespa({editor: {id: "editor"}})

        return

The main class for V3SPA framework.

    class Vespa
        constructor: (args) ->
            vespa = @

            @editor = new Editor 
                el: "#editor"

            @avispa = new Avispa
                el: $('#surface svg')

            $('#surface').append @avispa.$el

            # instantiate the models
            models.nodes     = new Models.Nodes
            models.positions = new Models.Positions
            models.links     = new Models.Links
            models.tasks     = new Models.Tasks

            # setup the dispatcher for websocket messages
            @dispatch = _.clone(Backbone.Events)

            @dispatch.on 'CreateDomain', @OnCreateDomain, @
            @dispatch.on 'UpdateDomain', @OnUpdateDomain, @
            @dispatch.on 'DeleteDomain', @OnDeleteDomain, @

            @dispatch.on 'CreatePort', @OnCreatePort, @
            @dispatch.on 'UpdatePort', @OnUpdatePort, @
            @dispatch.on 'DeletePort', @OnDeletePort, @

            @dispatch.on 'CreateLink', @OnCreateLink, @
            @dispatch.on 'UpdateLink', @OnUpdateLink, @
            @dispatch.on 'DeleteLink', @OnDeleteLink, @

            @dispatch.on 'UpdatePosition', @OnUpdatePosition, @
            @dispatch.on 'UpdateArc',      @OnUpdateArc,      @

            @connectionAttempts = 0
            @ConnectWS('lobster')

            # instantiate views and associate models
            #views.nodes = new Views.Node
            #    collection: models.nodes

            # load the boot-strapped model data
            #models.positions.reset _data.positions
            #models.nodes.reset     _data.nodes
            #models.links.reset     _data.links

            new Router()
            Backbone.history.start()

            return @

        OnCreateDomain: (id, parent, obj) ->
            domain = new Domain
                _id: id
                parent: parent
                name: obj.name
                position: obj.coords

            objects[id] = domain

            #if parent
            #then parent.$el.append domain.$el
            #else vespa.avispa.$objects.append domain.$el
            vespa.avispa.$groups.append domain.$el

            return

        OnCreatePort: (id, parent, obj) ->
            port = new Port
                _id: id
                parent: parent
                label: id
                position: obj.coords

            objects[id] = port

            #parent.$el.append port.$el
            vespa.avispa.$objects.append port.$el

            return

        OnCreateLink: (dir, left, right) ->
            link = new Avispa.Link
                direction: dir
                left: left
                right: right

            vespa.avispa.$links.append link.$el
            return

Establish a websocket connection to the server.  When a connection closes it
automatically attempts to reconnect.

        ConnectWS: (channel) ->
            @timeout = Math.min(@timeout + 1, 30)

            try
                host = "ws://#{location.host}/ws/#{channel}"
                @ws = new WebSocket(host)
                @timeout = 0

            catch error
                console.log('Connection failed')
                return

            @ws.onmessage = (event) =>
                msg = JSON.parse(event.data)
                @dispatch.trigger(msg.action, msg)
                return

            @ws.onclose = (event) =>
                setTimeout () =>
                    @ConnectWS(channel)
                  ,
                    1000 * @timeout
                return

            return
