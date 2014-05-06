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

Force a redraw on all the children

            for id of data.result.domains[data.result.root].subdomains
              do (id)->
                _.each $scope.objects.domains[id].children, (child)->
                  child.ParentDrag()

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
              _id: if obj?.path then obj.path else id
              parent: parents[0]
              name: if obj?.name then obj.name else "[#{id}]"
              position: coords
              data: if obj? then obj else null
              klasses: ['filtered'] unless obj?

          $scope.objects.domains[id] = domain

          if obj.path # this means it's not collapsed.
            IDEBackend.add_selection_range_object 'dsl', obj.srcloc.start.line, domain

          $scope.avispa.$groups.append domain.$el

      $scope.createPort = (id, parents, obj, coords) ->
          port = new Port
              _id: obj.path
              parent: parents[0]
              label: obj.name
              position: coords
              data: obj

          $scope.objects.ports[id] = port

          IDEBackend.add_selection_range_object 'dsl', obj.srcloc.start.line, port
          $scope.avispa.$objects.append port.$el

          return port

      $scope.createLink = (dir, left, right, data) ->
          link = new Avispa.Link
              direction: dir
              left: left
              right: right
              data: data

          IDEBackend.add_selection_range_object 'dsl', data.srcloc.start.line, link
          $scope.avispa.$links.append link.$el

Use D3's force-direction to layout a set of objects within the bounds.
Bounds is expected to be an object that contains 'w' and 'h' values for
width and height respectively

`keyfunc` is a method which returns the descriptive key, when given
the first two arguments of the \_.each callback. This allows disambiguation
between lists and objects.

      $scope.layout_objects = (objects, bounds, type='object', calc_bounds)->

          layout_model = []
          _.each objects, (val, key)->
              key = val if type == 'array'
              layout_model.push
                  x: 0
                  y: 0
                  px: 0
                  py: 0
                  key: key

          collide = (node)->
            [nx1, nx2, ny1, ny2] = calc_bounds(node)

            return (quad, x1, y1, x2, y2)->
              if quad.point and (quad.point != node)
                x = node.x - quad.point.x
                y = node.y - quad.point.y
                l = Math.sqrt(x * x + y * y)
                r = (nx2 - nx1)

                if l < r
                  l = (l - r) / l * .5
                  x *= l
                  y *= l
                  node.x -= x
                  node.y -= y
                  quad.point.x += x
                  quad.point.y += y
              return x1 > nx2 || x2 < nx1 || y1 > ny2 || y2 < ny1

          force = d3.layout.force().nodes(layout_model)
                      .size([bounds.w, bounds.h])
                      .gravity(0.05)
                      .charge(-1 * bounds.w)
                      .on('tick', ->
                          i = 0

                          for port in layout_model
                            #q.visit(collide(port))

                            if port.x > bounds.w
                              port.x = bounds.w
                            else if port.x < 0
                              port.x = 0
                            if port.y > bounds.h
                              port.y = bounds.h
                            else if port.y < 0
                              port.y = 0
                      )

          force.start()
          ctr = 0
          while force.alpha() > 0.01
            force.tick()
            ctr++
          console.log "Force ticked #{ctr} times"
          force.stop()

          return layout_model

      $scope.parseDomain = (domain) ->

          subdomain_count = _.size domain.subdomains
          port_count = _.size domain.ports

          size = Math.ceil(Math.sqrt(subdomain_count)) + 1
          domain_pos =
              w: size * 220
              h: size * 220

          console.log "Layout subdomains of #{domain.path} in bounds ", domain_pos
          subdomain_layout = $scope.layout_objects(
            domain.subdomains, domain_pos, 'object', (n)->
              return [n.x, n.x + 220, n.y, n.y + 220]
          )

          for layout in subdomain_layout
            do (layout)->
              console.log("X: #{layout.x}, Y: #{layout.y}")
              subdomain = domain.subdomains[layout.key]
              coords =
                  offset_x: layout.x
                  offset_y: layout.y

              if layout.key not of $scope.policy_data.domains
                coords.w = 50
                coords.h = 50

                $scope.createDomain layout.key, $scope.parent, subdomain, coords

              else

                subdomain = $scope.policy_data.domains[layout.key]

                subdomain_count = _.size subdomain.subdomains
                size = Math.ceil(Math.sqrt(subdomain_count)) + 1
                coords =
                    offset_x: layout.x
                    offset_y: layout.y
                    w: (200 * 1.1) * size || 200
                    h: (200 * 1.1) * size || 200

                $scope.createDomain layout.key, $scope.parent, subdomain, coords

                # Set the width and height directly - it changes based on the
                # number of subnodes, and otherwise it will be cached
                $scope.objects.domains[layout.key].position.set
                  w: (200 * 1.1) * size || 200
                  h: (200 * 1.1) * size || 200

                $scope.parent.unshift $scope.objects.domains[layout.key]
                $scope.parseDomain(subdomain)
                $scope.parent.shift()

Now layout the ports in this domain.

          console.log "Layout ports for #{domain.path} in bounds ", domain_pos
          port_layout = $scope.layout_objects(
            domain.ports, domain_pos, 'array', (n)->
              return [n.x - 15, n.x + 15, n.y - 15, n.y + 15]
          )

          for layout in port_layout
              port = $scope.policy_data.ports[layout.key]
              coords =
                  offset_x: layout.x
                  offset_y: layout.y
                  radius: 30
                  fill: '#eeeeec'

              $scope.createPort layout.key,  $scope.parent, port, coords


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
            vals,
            ['x', 'y', 'w', 'h']
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
        changed = false
        if @posMgr?
          changed = @posMgr.update(obj)
        else
          for k, v of obj
            do (k, v)->
              if @data[k] != v
                @data[k] = v
                changed = true

          # This is intentionally inside the else block.
          # posMgr notifies any of its changes
          if changed
            @notify(['change'])

    Port = Avispa.Node

    Domain = Avispa.Group.extend

        init: () ->

            @$label = $SVG('text')
                .attr('dx', '0.5em')
                .attr('dy', '1.5em')
                .text(@options.name or @options.id)
                .appendTo(@$el)

            return @

        render: () ->
            pos = @AbsPosition()
            @$rect
                .attr('x', pos.x)
                .attr('y', pos.y)
                .attr('width',  @position.get('w'))
                .attr('height', @position.get('h'))
            @$label
                .attr('x', pos.x)
                .attr('y', pos.y)
            return @

