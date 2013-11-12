// Generated by CoffeeScript 1.6.3
(function() {
  var Dialogs, Domain, Editor, Parser, Port, Router, Vespa, Views, models, objects, templates, vespa, views;

  window.Models = {};

  Views = {};

  Dialogs = {};

  objects = {};

  models = {};

  views = {};

  templates = {};

  vespa = null;

  $(document).ready(function() {
    var flip;
    flip = true;
    $('#expand').on('click', function() {
      return $('#status_pane').animate({
        height: flip ? "+=8em" : "-=8em"
      }, 200, function() {
        return flip = !flip;
      });
    });
    templates = {
      editor: $('#tmpl_editor').text()
    };
    if (vespa == null) {
      vespa = new Vespa();
    }
  });

  Vespa = (function() {
    function Vespa() {
      vespa = this;
      this.avispa = new Avispa({
        el: $('#surface svg')
      });
      $('#surface').append(this.avispa.$el);
      models.nodes = new Models.Nodes;
      models.positions = new Models.Positions;
      models.links = new Models.Links;
      models.tasks = new Models.Tasks;
      this.dispatch = _.clone(Backbone.Events);
      this.dispatch.on('CreateDomain', this.OnCreateDomain, this);
      this.dispatch.on('UpdateDomain', this.OnUpdateDomain, this);
      this.dispatch.on('DeleteDomain', this.OnDeleteDomain, this);
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
      this.ConnectWS('lobster');
      new Router();
      Backbone.history.start();
      return this;
    }

    Vespa.prototype.OnCreateDomain = function(id, parent, obj) {
      var domain;
      domain = new Domain({
        _id: id,
        name: obj.name,
        position: obj.coords
      });
      objects[id] = domain;
      parent.append(domain.$el);
    };

    Vespa.prototype.OnCreateNode = function(id, parent, obj) {
      var node;
      node = new Avispa.Node({
        _id: id,
        parent: parent,
        label: id,
        position: obj.coords
      });
      objects[id] = node;
      parent.append(node.$el);
    };

    Vespa.prototype.ConnectWS = function(channel) {
      var error, host,
        _this = this;
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
        _this.dispatch.trigger(msg.action, msg);
      };
      this.ws.onclose = function(event) {
        setTimeout(function() {
          return _this.ConnectWS(channel);
        }, 1000 * _this.timeout);
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

  Router = Backbone.Router.extend({
    routes: {
      'editor': 'editor',
      'node': 'node',
      'load/:example': 'load',
      'logout': 'logout',
      '': 'main'
    },
    initialize: function() {
      this.modal = $('#modal');
      this.editor = null;
    },
    cleanse: function() {},
    main: function() {
      return this.cleanse();
    },
    editor: function() {
      this.cleanse();
      if (!this.editor) {
        return this.editor = new Editor;
      }
    },
    load: function(example) {
      $.ajax({
        url: "/static/data/" + example + ".lsr.json",
        success: function(lsr) {
          return Parser.Load(lsr);
        }
      });
    },
    node: function() {},
    logout: function() {
      return window.location = '/logout';
    }
  });

  Parser = {
    Load: function(lsr) {
      this.parent = [vespa.avispa.$objects];
      this.Domain(lsr);
    },
    Domain: function(domain) {
      var id, port, subdomain, _ref, _ref1;
      _ref = domain.subdomains;
      for (id in _ref) {
        subdomain = _ref[id];
        subdomain.coords = {
          x: 70,
          y: 60,
          w: 200,
          h: 200
        };
        vespa.dispatch.trigger('CreateDomain', id, this.parent[0], subdomain);
        this.parent.unshift(objects[id].$el);
        this.Domain(subdomain);
        this.parent.shift();
      }
      _ref1 = domain.ports;
      for (id in _ref1) {
        port = _ref1[id];
        port.coords = {
          x: 40,
          y: 40,
          radius: 30,
          fill: '#eeeeec'
        };
        vespa.dispatch.trigger('CreateNode', id, this.parent[0], port);
      }
    }
  };

  Domain = Avispa.Group.extend({
    init: function() {
      this.$el.append($SVG('rect').attr('width', this.position.get('w')).attr('height', this.position.get('h')).css('fill', this.position.get('fill')));
      this.$el.append($SVG('text').attr('dx', '2em').attr('dy', '1em').text(this.options.name));
      return this;
    }
  });

  Port = Avispa.Node.extend;

  Editor = Backbone.View.extend({
    id: 'editor',
    className: 'dialog',
    initialize: function() {
      this.$el.attr('title', 'Editor').html('<textarea resizable="0"></textarea>').dialog({
        resizable: true,
        width: 400,
        minWidth: 400,
        height: 400,
        minHeight: 400,
        modal: false,
        hide: {
          effect: 'fade',
          duration: 200
        },
        buttons: {
          'Update': function() {
            return $(this).dialog("close");
          },
          'Cancel': function() {
            return $(this).dialog("close");
          }
        }
      });
      return this;
    }
  });

}).call(this);
