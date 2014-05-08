    vespaControllers = angular.module('vespaControllers')

    vespaControllers.controller 'avispaCtrl', ($scope, VespaLogger,
        IDEBackend, $timeout, PositionManager, $q) ->

      $scope.domain_data = null
      $scope.objects ?=
          ports: {}
          domains: {}
          connections: {}
      $scope.parent ?= [null]

      $scope.avispa = new Avispa
        el: $('#surface svg.avispa')

      $('#surface').append $scope.avispa.$el

Manage the position of items within this view.

Clean up the Avispa view

      cleanup = ->
          $scope.objects =
              ports: {}
              domains: {}
              connections: {}
          $scope.parent = [null]

          $('#surface svg.avispa .objects')[0].innerHTML = ''
          $('#surface svg.avispa .links')[0].innerHTML = ''
          $('#surface svg.avispa .labels')[0].innerHTML = ''
          $('#surface svg.avispa .groups')[0].innerHTML = ''


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

            viewport_pos = PositionManager(
                "avispa.viewport::#{IDEBackend.current_policy._id}"
            )
            viewport_pos.retrieve().then ->
                $scope.avispa = new Avispa
                  el: $('#surface svg.avispa')
                  position: viewport_pos

            root_id = data.result.root

            $scope.parseRootDomain root_id, data.result.domains[root_id]

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

          return domain

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

          link_pos = PositionManager(
              "avispa.link:#{data.left}-#{data.right}:" + 
              "#{IDEBackend.current_policy._id}"
              {arc: 10},
              true
          )

          link = new Avispa.Link
              direction: dir
              left: left
              right: right
              data: data
              position: link_pos

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
                            q.visit(collide(port))

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

      $scope.parseRootDomain = (id, domain) ->

          position_defers = []
          domain_objects = []
          subdomain_defers = []

          _.each domain.subdomains, (subd, id)->
              $scope.parent.unshift null
              subdomain = $scope.parseDomain id, subd
              $scope.parent.shift()

              subdomain_defers.push subdomain

          _.each domain.ports, (port_id)->
              port = $scope.policy_data.ports[port_id]
              coords =
                  offset_x: 0
                  offset_y: 0
                  radius: 30
                  fill: '#eeeeec'

              port_pos = PositionManager(
                "avispa.#{id}::#{IDEBackend.current_policy._id}",
                coords,
                ['x', 'y', 'w', 'h']
              )
              position_defers.push port_pos.retrieve()

              port_obj = $scope.createPort port_id,  $scope.parent, port, port_pos

              domain_objects.push port_obj

This method returns a promise that will be resolved when all subdomains
have finished parsing *and* checking their server position values.
Since it's recursive, we check it in each method.

          parser_deferral = $q.defer() 

          $q.all(position_defers).then (deferrals)->
            for posobj in deferrals
              do (posobj)->
                if posobj.remote_update
                  posobj.data.data.fixed = true

            $q.all(subdomain_defers).then (subdoms)->
              domain_objects = _.extend domain_objects, subdoms

Now would be an opportune time to do layout
on the subnodes. For now just resolve the promise

              _.each domain_objects, (obj)->
                obj.render()

              parser_deferral.resolve true

          return parser_deferral.promise

      $scope.parseDomain = (id, domain, isRoot) ->

          domain_pos = PositionManager(
            "avispa.#{id}::#{IDEBackend.current_policy._id}",
            {offset_x: 10, offset_y: 10, w: 0, h: 0},
            ['x', 'y', 'w', 'h']
          )

          if id of $scope.policy_data.domains
            domain = $scope.policy_data.domains[id]
            domain.collapsed = false
          else
            domain.collapsed = true

          domain_obj = $scope.createDomain id, $scope.parent, domain, domain_pos

          position_defers = [domain_pos.retrieve()]
          domain_objects = []
          subdomain_defers = []

          _.each domain.subdomains, (subd, id)->
              $scope.parent.unshift domain_obj
              subdomain = $scope.parseDomain id, subd
              $scope.parent.shift()

              subdomain_defers.push subdomain

          _.each domain.ports, (port_id)->
              port = $scope.policy_data.ports[port_id]
              coords =
                  offset_x: 0
                  offset_y: 0
                  radius: 30
                  fill: '#eeeeec'

              port_pos = PositionManager(
                "avispa.#{id}::#{IDEBackend.current_policy._id}",
                coords,
                ['x', 'y', 'w', 'h']
              )
              position_defers.push port_pos.retrieve()

              port_obj = $scope.createPort port_id,  $scope.parent, port, port_pos

              domain_objects.push port_obj

This method returns a promise that will be resolved when all subdomains
have finished parsing *and* checking their server position values.
Since it's recursive, we check it in each method.

          parser_deferral = $q.defer() 

          $q.all(position_defers).then (deferrals)->
            for posobj in deferrals
              do (posobj)->
                if posobj.remote_update
                  posobj.data.data.fixed = true

            $q.all(subdomain_defers).then (subdoms)->
              domain_objects = _.extend domain_objects, subdoms

Set the size for the group. If there are no subelements, its size 1.
Otherwise it's 1.1 * ceil(sqrt(subelement_count)). If there are no

              if domain_obj.options.data.collapsed
                domain_obj.position.set
                    w: 100
                    h: 25
              else 
                if domain_objects.length == 0
                  size = 1
                else
                  size = Math.ceil(Math.sqrt(domain_objects.length)) + 1
                  size *= 1.1

                domain_obj.position.set
                    w: 200 * size
                    h: 200 * size

              if not domain_obj.position.get 'fixed'
                domain_obj.position.set
                  offset_x: 10
                  offset_y: 10

  We've calculated our size. Now would be an opportune time to do layout
  on the subnodes. For now just resolve the promise

              _.each domain_objects, (obj)->
                obj.render()

              parser_deferral.resolve(domain_obj)

          return parser_deferral.promise

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

    Port = Avispa.Node

    Domain = Avispa.Group.extend

        events:
          'mousedown'   : 'OnMouseDown'
          'mouseenter'  : 'OnMouseEnter'
          'mouseleave'  : 'OnMouseLeave'
          'mousedown .expandicon': 'Expand'

        init: () ->

            @$titlebar = $SVG('svg')
                .attr('width',  @position.get('w'))
                .attr('height', '25px')
                .attr('class', 'domainTitle')
                .attr('x', @position.get('x'))
                .attr('y', @position.get('y'))
                .appendTo(@$el)

            g = $SVG('g')

            $SVG('rect')
                .attr('width',  '100%')
                .attr('height', '25px')
                .attr('class', 'domainTitle')
                .appendTo(g)

            @$icon = $SVG('rect')
                .attr('x', @position.get('w') - 21)
                .attr('y', 5)
                .attr('width', '20')
                .attr('height', '20')
                .appendTo(g)

            @$label = $SVG('text')
                .attr('dx', '0.5em')
                .attr('dy', '1.5em')
                .text(@options.name or @options.id)
                .appendTo(g)

            g.appendTo(@$titlebar)

            return @

        render: () ->
            pos = @AbsPosition()
            @$rect
                .attr('x', pos.x)
                .attr('y', pos.y)
                .attr('width',  @position.get('w'))
                .attr('height', @position.get('h'))

            @$titlebar
                .attr('x', pos.x)
                .attr('y', pos.y)
                .attr('width',  @position.get('w'))

            @$icon
                .attr('x', @position.get('w') - 21)

            if @options.data.collapsed
              @$icon.attr('class', 'expandicon')
            else
              @$icon.attr('width', '0').attr('height', '0')

            return @

        Expand: (event)->
          context.ide_backend.expand_graph @AncestorList()

          cancelEvent(event)
