// Generated by CoffeeScript 1.6.3
(function() {
  var Dialogs, Models, Vespa, Views, models, templates, vespa, views;

  Models = {};

  Views = {};

  Dialogs = {};

  models = {};

  views = {};

  templates = {};

  vespa = null;

  $(document).ready(function() {
    if (vespa == null) {
      vespa = new Vespa();
    }
    templates = {
      graph_node_contextmenu: $('#template_graph_node_contextmenu').text(),
      graph_task_configure: $('#template_graph_task_configure').text()
    };
  });

  Vespa = (function() {
    function Vespa() {
      models.nodes = new Models.Nodes;
      models.positions = new Models.Positions;
      models.links = new Models.Links;
      models.arcs = new Models.Arcs;
      models.tasks = new Models.Tasks;
      this.dispatch = _.clone(Backbone.Events);
      this.dispatch.on('CreateNode', this.OnCreateNode, this);
      this.dispatch.on('UpdateNode', this.OnUpdateNode, this);
      this.dispatch.on('DeleteNode', this.OnDeleteNode, this);
      this.dispatch.on('UpdateNodeText', this.OnUpdateNodeText, this);
      this.dispatch.on('CreateLink', this.OnCreateLink, this);
      this.dispatch.on('UpdateLink', this.OnUpdateLink, this);
      this.dispatch.on('DeleteLink', this.OnDeleteLink, this);
      this.dispatch.on('UpdatePosition', this.OnUpdatePosition, this);
      this.dispatch.on('UpdateArc', this.OnUpdateArc, this);
      this.connectionAttempts = 0;
      this.WebsocketConnect();
      views.graph = new Views.Graph;
      models.positions.reset(_data.positions);
      models.arcs.reset(_data.arcs);
      models.nodes.reset(_data.nodes);
      models.links.reset(_data.links);
      return;
    }

    Vespa.prototype.ConnectWS = function(channel) {
      var error, host;
      this.timeout = Math.min(this.timeout + 1, 30);
      try {
        host = "ws://" + location.host + "/ws/" + channel;
        this.ws = new WebSocket(host);
        this.timeout = 0;
      } catch (_error) {
        error = _error;
        console.log('Connection failed');
        return;
      }
      this.ws.onmessage = function(event) {
        var msg;
        msg = JSON.parse(event.data);
        controller.dispatch.trigger(msg.action, msg);
      };
      this.ws.onclose = function(event) {
        setTimeout(function() {
          return controller.ConnectWS(channel);
        }, 1000 * this.timeout);
      };
    };

    return Vespa;

  })();

  Models.Node = Backbone.DeepModel.extend({
    idAttribute: '_id',
    urlRoot: '/data/nodes/'
  });

  Models.Nodes = Backbone.Collection.extend({
    model: Models.Node
  });

  Models.Controller = Backbone.DeepModel.extend({
    idAttribute: '_id',
    urlRoot: '/data/controllers/'
  });

  Models.Controllers = Backbone.Collection.extend({
    model: Models.Controller
  });

  Models.Link = Backbone.DeepModel.extend({
    idAttribute: '_id',
    urlRoot: '/data/links/'
  });

  Models.Links = Backbone.Collection.extend({
    model: Models.Link
  });

  Models.Task = Backbone.DeepModel.extend({
    idAttribute: '_id',
    urlRoot: '/data/tasks/'
  });

  Models.Tasks = Backbone.Collection.extend({
    model: Models.Task,
    url: '/data/tasks/'
  });

  Models.Response = Backbone.DeepModel.extend({
    idAttribute: '_id',
    urlRoot: '/data/response/'
  });

  Models.Responses = Backbone.DeepModel.extend({
    idAttribute: '_id',
    urlRoot: '/data/responses/'
  });

  Models.Position = Backbone.Model.extend({
    idAttribute: '_id',
    urlRoot: '/data/position/'
  });

  Models.Positions = Backbone.Collection.extend({
    model: Models.Position
  });

  Models.Arc = Backbone.Model.extend({
    idAttribute: '_id',
    urlRoot: '/data/arc/'
  });

  Models.Arcs = Backbone.Collection.extend({
    model: Models.Arc
  });

}).call(this);
