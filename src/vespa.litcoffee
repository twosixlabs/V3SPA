
    Models  = {}
    Views   = {}
    Dialogs = {}

    models    = {}
    views     = {}
    templates = {}

    vespa = null

    #DT.Views.Plugins['controller'] = Backbone.View.extend
    #    initialize: () ->
    #        controller ?= new Controller()
    #        @$el = views.graph.$el
    #        return


This is the entry point into the V3SPA framework.

    $(document).ready () ->
        vespa ?= new Vespa()

        # pre-compile the templates
        templates =
            graph_node_contextmenu: $( '#template_graph_node_contextmenu' ).text()
            graph_task_configure:   $( '#template_graph_task_configure'   ).text()

        return

The main class for V3SPA framework.

    class Vespa
        constructor: () ->

            # instantiate the models
            models.nodes     = new Models.Nodes
            models.positions = new Models.Positions
            models.links     = new Models.Links
            models.arcs      = new Models.Arcs
            models.tasks     = new Models.Tasks

            # setup the dispatcher for websocket messages
            @dispatch = _.clone(Backbone.Events)

            @dispatch.on 'CreateNode', @OnCreateNode, @
            @dispatch.on 'UpdateNode', @OnUpdateNode, @
            @dispatch.on 'DeleteNode', @OnDeleteNode, @

            @dispatch.on 'UpdateNodeText', @OnUpdateNodeText, @

            @dispatch.on 'CreateLink', @OnCreateLink, @
            @dispatch.on 'UpdateLink', @OnUpdateLink, @
            @dispatch.on 'DeleteLink', @OnDeleteLink, @

            @dispatch.on 'UpdatePosition', @OnUpdatePosition, @
            @dispatch.on 'UpdateArc',      @OnUpdateArc,      @

            @connectionAttempts = 0
            @WebsocketConnect()

            views.graph = new Views.Graph

            # instantiate views and associate models
            #views.nodes = new Views.Node
            #    collection: models.nodes

            # load the boot-strapped model data
            models.positions.reset _data.positions
            models.arcs.reset      _data.arcs
            models.nodes.reset     _data.nodes
            models.links.reset     _data.links

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

            @ws.onmessage = (event) ->
                msg = JSON.parse(event.data)
                controller.dispatch.trigger(msg.action, msg)
                return

            @ws.onclose = (event) ->
                setTimeout () ->
                    controller.ConnectWS(channel)
                  ,
                    1000 * @timeout
                return

            return
