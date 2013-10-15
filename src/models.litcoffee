
Backbone models that use the CRUD paradigm

    Models.Node = Backbone.DeepModel.extend
        idAttribute: '_id'
        urlRoot: '/data/nodes/'

    Models.Nodes = Backbone.Collection.extend
        model: Models.Node

    Models.Controller = Backbone.DeepModel.extend
        idAttribute: '_id'
        urlRoot: '/data/controllers/'

    Models.Controllers = Backbone.Collection.extend
        model: Models.Controller


    Models.Link = Backbone.DeepModel.extend
        idAttribute: '_id'
        urlRoot: '/data/links/'

    Models.Links = Backbone.Collection.extend
        model: Models.Link


    Models.Task = Backbone.DeepModel.extend
        idAttribute: '_id'
        urlRoot: '/data/tasks/'

    Models.Tasks = Backbone.Collection.extend
        model: Models.Task
        url: '/data/tasks/'


    Models.Response = Backbone.DeepModel.extend
        idAttribute: '_id'
        urlRoot: '/data/response/'

    Models.Responses = Backbone.DeepModel.extend
        idAttribute: '_id'
        urlRoot: '/data/responses/'


    Models.Position = Backbone.Model.extend
        idAttribute: '_id'
        urlRoot: '/data/position/'

    Models.Positions = Backbone.Collection.extend
        model: Models.Position


    Models.Arc = Backbone.Model.extend
        idAttribute: '_id'
        urlRoot: '/data/arc/'

    Models.Arcs = Backbone.Collection.extend
        model: Models.Arc
