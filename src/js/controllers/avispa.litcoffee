    vespaControllers = angular.module('vespaControllers')

    vespaControllers.controller 'avispaCtrl', ($scope, VespaLogger,
        IDEBackend, $timeout) ->

      $scope.objects ?= {}
      $scope.parent ?= [null]

      $scope.avispa = new Avispa
        el: $('#surface svg')

      $('#surface').append $scope.avispa.$el

Clean up the Avispa view

      cleanup = ->
          $scope.objects = {}
          $scope.parent = [null]

          $('#surface svg .objects')[0].innerHTML = ''
          $('#surface svg .links')[0].innerHTML = ''
          $('#surface svg .labels')[0].innerHTML = ''
          $('#surface svg .groups')[0].innerHTML = ''


A general update function for the Avispa view.

      update_view = (data)->

        if data.domain
          cleanup()
          $scope.avispa = new Avispa
            el: $('#surface svg')

          $scope.parseDomain(data.domain)

        else
          cleanup()


      IDEBackend.add_hook "json_changed", update_view
      $scope.$on "$destroy", ->
        IDEBackend.unhook "json_changed", update_view

      start_data = IDEBackend.get_json()
      if start_data
        $timeout ->
          update_view(start_data)

The following is more or less mapped from the backbone style code.
ID's MUST be fully qualified, or Avispa renders horribly wrong.

      fqid = (id, parent)->
        if parent?
          return "#{parent.options._id}.#{id}"
        else
          return id

      $scope.createDomain = (id, parents, obj) ->
          uid = fqid(id, parents[0])
          domain = new Domain
              _id: uid
              parent: parents[0]
              name: obj.name
              position: obj.coords

          $scope.objects[uid] = domain

          #if parent
          #then parent.$el.append domain.$el
          #else vespa.avispa.$objects.append domain.$el
          $scope.avispa.$groups.append domain.$el

      $scope.createPort = (id, parents, obj) ->
          uid = fqid(id, parents[0])
          port = new Port
              _id: uid
              parent: parents[0]
              label: id
              position: obj.coords

          $scope.objects[uid] = port

          #parent.$el.append port.$el
          $scope.avispa.$objects.append port.$el

      $scope.createLink = (dir, left, right) ->
          link = new Avispa.Link
              direction: dir
              left: left
              right: right

          $scope.avispa.$links.append link.$el

      $scope.parseDomain = (domain) ->
          domains = x: 10
          bounds = x: 40, y: 40

          for id,subdomain of domain.subdomains
              subdomain.coords =
                  x: domains.x
                  y: 100
                  w: 220 * Object.keys(subdomain.subdomains).length || 200
                  h: 220 * Object.keys(subdomain.subdomains).length || 200

              $scope.createDomain subdomain.name, $scope.parent, subdomain

              subdomain_id = fqid subdomain.name, $scope.parent[0]
              $scope.parent.unshift $scope.objects[subdomain_id]
              $scope.parseDomain(subdomain)
              $scope.parent.shift()

              domains.x += 210

          for id, port of domain.ports
              port.coords =
                  x: bounds.x
                  y: bounds.y
                  radius: 30
                  fill: '#eeeeec'

              $scope.createPort id,  $scope.parent, port

              bounds.x += 70

Get the object id of the port which this connection is connected
to. This can either be a FQN (<domain>.<port>) or a local port name,
(just <port>).

          get_port_id = (parent, connection)->
            parent_fqid = fqid("", $scope.parent[0])
            if connection.domain?
              return parent_fqid + "#{parent.subdomains[connection.domain].name}.#{connection.port}"
            else
              return parent_fqid + "#{connection.port}"

          for idx,connection of domain.connections
              $scope.createLink connection.connection,
                  $scope.objects[get_port_id(domain,connection.left)],
                  $scope.objects[get_port_id(domain,connection.right)]

Lobster-specific definitions for Avispa

    class GenericModel
      constructor: (vals)->
        @observers = {}
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

