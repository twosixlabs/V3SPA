    vespaControllers = angular.module('vespaControllers')

    vespaControllers.controller 'avispaCtrl', ($scope, VespaLogger,
        IDEBackend, $timeout) ->

      $scope.domain_data = null
      $scope.objects ?= 
          ports: {}
          domains: {}
          connections: {}
      $scope.parent ?= [null]

      $scope.avispa = new Avispa
        el: $('#surface svg')

      $('#surface').append $scope.avispa.$el

Manage the position of items within this view.

Clean up the Avispa view

      cleanup = ->
          $scope.objects =
              ports: {}
              domains: {}
              connections: {}
          $scope.parent = [null]

          $('#surface svg .objects')[0].innerHTML = ''
          $('#surface svg .links')[0].innerHTML = ''
          $('#surface svg .labels')[0].innerHTML = ''
          $('#surface svg .groups')[0].innerHTML = ''


A general update function for the Avispa view. This only refreshes
when the domain data has actually changed to prevent flickering.

      update_view = (data)->
        if _.size(data.errors) > 0
            $scope.policy_data = null
            cleanup()

        else
          if not _.isEqual(data.result, $scope.policy_data)
            $scope.policy_data = data.result

            cleanup()
            $scope.avispa = new Avispa
              el: $('#surface svg')

            $scope.parseDomain(data.result.domains[data.result.root])
            $scope.parseConns(data.result.connections)


      IDEBackend.add_hook "json_changed", update_view
      $scope.$on "$destroy", ->
        IDEBackend.unhook "json_changed", update_view

The following is more or less mapped from the backbone style code.
ID's MUST be fully qualified, or Avispa renders horribly wrong.

      fqid = (id, parent)->
        if parent?
          return "#{parent.options._id}.#{id}"
        else
          return id

      $scope.createDomain = (id, parents, obj, coords) ->
          domain = new Domain
              _id: obj.path
              parent: parents[0]
              name: obj.name
              position: coords
              data: obj

          $scope.objects.domains[id] = domain

          #if parent
          #then parent.$el.append domain.$el
          #else vespa.avispa.$objects.append domain.$el
          $scope.avispa.$groups.append domain.$el

      $scope.createPort = (id, parents, obj, coords) ->
          port = new Port
              _id: obj.path
              parent: parents[0]
              label: obj.name
              position: coords
              data: obj

          $scope.objects.ports[id] = port

          #parent.$el.append port.$el
          $scope.avispa.$objects.append port.$el

      $scope.createLink = (dir, left, right, data) ->
          link = new Avispa.Link
              direction: dir
              left: left
              right: right
              data: data

          $scope.avispa.$links.append link.$el

      $scope.parseDomain = (domain) ->
          domains = x: 10
          bounds = x: 40, y: 40

          for id in domain.subdomains
            do (id)->
              subdomain = $scope.policy_data.domains[id]
              coords =
                  x: domains.x
                  y: 100
                  w: 220 * subdomain.subdomains.length || 200
                  h: 220 * subdomain.subdomains.length || 200

              $scope.createDomain id, $scope.parent, subdomain, coords

              $scope.parent.unshift $scope.objects.domains[id]
              $scope.parseDomain(subdomain)
              $scope.parent.shift()

              domains.x += 210

          for id in domain.ports
              port = $scope.policy_data.ports[id]
              coords =
                  x: bounds.x
                  y: bounds.y
                  radius: 30
                  fill: '#eeeeec'

              $scope.createPort id,  $scope.parent, port, coords

              bounds.x += 70


      $scope.parseConns = (connections)->

          for connection in connections
              $scope.createLink connection.connection,
                                $scope.objects.ports[connection.left],
                                $scope.objects.ports[connection.right],
                                connection

Actually load the thing the first time.

      start_data = IDEBackend.get_json()
      if start_data
          update_view(start_data)

Lobster-specific definitions for Avispa

    class GenericModel
      constructor: (vals, identifier)->
        @observers = {}

If we have an identifier, then instantiate a PositionManager
and use it's data variable as the data variable. Otherwise just
store it locally.

        if identifier?
We are outside of Angular, so we need to retrieve the services
from the injector

          injector = angular.element('body').injector()
          PositionManager = injector.get('PositionManager')
          IDEBackend = injector.get('IDEBackend')

          @posMgr = PositionManager(
            "avispa.#{identifier}::#{IDEBackend.current_policy._id}",
            vals
          )
          @data = @posMgr.data

          @posMgr.on_change =>
            @notify ['change']

        else
          @data = vals

      bind: (event, func, _this)->
        @observers[event] ?= []
        @observers[event].push([ _this, func ])

      notify: (event)->
        for observer in @observers[event]
          do (observer)=>
            observer[1].apply observer[0], [@]

      get: (key)->
        return @data[key]

      set: (obj)->
        @_set(obj)

      _set: (obj)->
        if @posMgr?
          @posMgr.update(obj)
        else
          for k, v of obj
            @data[k] = v

        @notify(['change'])

    Port = Avispa.Node

    Domain = Avispa.Group.extend

        init: () ->

            @$label = $SVG('text')
                .attr('dx', '0.5em')
                .attr('dy', '1.5em')
                .text(@options.name)
                .appendTo(@$el)

            return @

        render: () ->
            @$rect
                .attr('x', @position.get('x'))
                .attr('y', @position.get('y'))
            @$label
                .attr('x', @position.get('x'))
                .attr('y', @position.get('y'))
            return @

