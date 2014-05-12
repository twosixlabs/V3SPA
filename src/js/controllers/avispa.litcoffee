    vespaControllers = angular.module('vespaControllers')

    vespaControllers.controller 'avispaCtrl', ($scope, VespaLogger,
        IDEBackend, $timeout, PositionManager, $q) ->

      $scope.domain_data = null
      $scope.objects ?=
          ports_by_path: {}
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
              ports_by_path: {}
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
                "avispa.viewport::#{IDEBackend.current_policy._id}",
                {a: 1, b: 0, c: 0, d: 1, e: 0, f: 0}
            )

            viewport_pos.retrieve().then ->
                $scope.avispa = new Avispa
                  el: $('#surface svg.avispa')
                  position: viewport_pos

            root_id = data.result.root

            $scope.parseRootDomain root_id, data.result.domains[root_id]

Force a redraw on all the children


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
          $scope.objects.ports_by_path[obj.path] = port

          IDEBackend.add_selection_range_object 'dsl', obj.srcloc.start.line, port
          $scope.avispa.$objects.append port.$el

          return port

      $scope.createLink = (dir, left, right, data) ->

Sometimes the endpoints of links don't exist because they're collapsed.
When this happens, don't actually make the link. Instead, label
the endpoint that does exist so that it can obviously be expanded

          if not right 
            left.add_class 'expandable'
            left.$el/cont
            #clicked = $scope.objects.ports_by_path[target.id]
            #missing_conns = _.omit $scope.policy_data.connections, (c)->
            #  c.left of $scope.objects.ports and conn.right of $scope.objects.ports


          else if not left
            right.add_class 'expandable'

          else

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
                  x: val.position.get('offset_x')
                  y: val.position.get('offset_y')
                  fixed: val.position.get('fixed')
                  key: key

          force = d3.layout.force()
          force = force.nodes(layout_model)
          force = force.size([bounds.w, bounds.h])
          force = force.gravity(0.05)
          force = force.charge(-100)

          force.start()
          ctr = 0
          while force.alpha() > 0.01
            force.tick()
            ctr++
          console.log "Force ticked #{ctr} times"
          force.stop()

          return layout_model

      $scope.parseRootDomain = (id, domain) ->

          root = new Avispa.BaseObject
            parent: null
            position: PositionManager(
                "avispa.root::#{IDEBackend.current_policy._id}",
                {offset_x: 0, offset_y: 0},
                ['x', 'y', 'w', 'h']
              )          
            fake_container: true


          position_defers = []
          domain_objects = []
          subdomain_defers = []

          _.each domain.subdomains, (subd, id)->
              $scope.parent.unshift root
              subdomain = $scope.parseDomain id, subd
              $scope.parent.shift()

              subdomain_defers.push subdomain

          $scope.parent.unshift root
          _.each domain.ports, (port_id)->
              port = $scope.policy_data.ports[port_id]
              coords =
                  offset_x: 0
                  offset_y: 0
                  radius: 30

              port_pos = PositionManager(
                "avispa.port.#{port_id}::#{IDEBackend.current_policy._id}",
                coords,
                ['x', 'y', 'w', 'h']
              )
              position_defers.push port_pos.retrieve()

              port_obj = $scope.createPort port_id,  $scope.parent, port, port_pos

              domain_objects.push port_obj


          #_.each root.children, (child)->
          #  child.ParentDrag()

          $scope.parent.shift()

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
              domain_objects = _.union domain_objects, subdoms

Now would be an opportune time to do layout
on the subnodes. For now just resolve the promise


              if domain_objects.length > 1
                layout = $scope.layout_objects domain_objects, {w: 1, h: 1}
                _.each layout, (model)->
                  pos =
                    offset_x: model.x
                    offset_y: model.y
                  domain_objects[model.index].position.set pos, true

              _.each domain_objects, (obj)->
                obj.ParentDrag()

              parser_deferral.resolve true

          return parser_deferral.promise

      $scope.parseDomain = (id, domain, isRoot) ->

          domain_pos = PositionManager(
            "avispa.domain.#{id}::#{IDEBackend.current_policy._id}",
            {offset_x: 10, offset_y: 10, w: 0, h: 0},
            ['x', 'y', 'w', 'h']
          )

          console.log "Created PositionManager: avispa.domain.#{id}::#{IDEBackend.current_policy._id}"

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

          $scope.parent.unshift domain_obj
          _.each domain.ports, (port_id)->
              port = $scope.policy_data.ports[port_id]
              coords =
                  offset_x: 0
                  offset_y: 0
                  radius: 30

              port_pos = PositionManager(
                "avispa.port.#{port_id}::#{IDEBackend.current_policy._id}",
                coords,
                ['x', 'y', 'w', 'h']
              )
              position_defers.push port_pos.retrieve()

              port_obj = $scope.createPort port_id,  $scope.parent, port, port_pos

              domain_objects.push port_obj
              console.log "After port push: ", domain_objects

          $scope.parent.shift()

          console.log "Domain objects: ", domain_objects

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
              if domain_objects.length > 0 
                console.log domain_objects
              domain_objects = _.union domain_objects, subdoms

              console.log "Domain objects after deferral : ", domain_objects

Set the size for the group. If there are no subelements, its size 1.
Otherwise it's 1.1 * ceil(sqrt(subelement_count)). If there are no

              if domain_obj.options.data.collapsed
                bounds = 
                    w: Math.max(100, 10 * domain_obj.options.name.length)
                    h: 25
              else 
                if domain_objects.length == 0
                  width = height = 200

                else
                  area_sum = (memo, next)->
                    return memo + (next.width() * next.height())
                  sum = (memo, next)->
                      return [memo[0] + next.width(), memo[1] + next.height()]

                  [width, height] = _.reduce domain_objects, sum, [0, 0]
                  area = _.reduce domain_objects, area_sum, 0

                  if domain_objects.length > 5

                    width = Math.sqrt(area)
                    height = Math.sqrt(area)

                bounds = 
                    w:  width * 1.5
                    h:  (height * 1.5) + 25

              domain_obj.position.set bounds, false


              if domain_objects.length > 1
                layout = $scope.layout_objects domain_objects, bounds
                _.each layout, (model)->
                  pos =
                    offset_x: model.x
                    offset_y: model.y
                  domain_objects[model.index].position.set pos

              domain_obj.ParentDrag()

  We've calculated our size. Now would be an opportune time to do layout
  on the subnodes. For now just resolve the promise

              #_.each domain_objects, (obj)->
              #  obj.render()

              parser_deferral.resolve(domain_obj)

          return parser_deferral.promise

      $scope.parseConns = (connections)->

          _.each connections, (connection)->

              $scope.createLink connection.connection,
                                $scope.objects.ports[connection.left],
                                $scope.objects.ports[connection.right],
                                connection

Actually load the thing the first time.

      start_data = IDEBackend.get_json()
      if start_data
          update_view(start_data)

Lobster-specific definitions for Avispa


    Port = Avispa.Node.extend

       OnRightClick: (event)->
         #console.log "Right click!"

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

            @$label = $SVG('text')
                .attr('dx', '0.5em')
                .attr('dy', '1.5em')
                .text(@options.name or @options.id)
                .appendTo(g)

            @$icon = $SVG('rect')
                .attr('x', @position.get('w') - 21)
                .attr('y', 5)
                .attr('width', '20')
                .attr('height', '20')
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
          Avispa.context.ide_backend.expand_graph @AncestorList()

          cancelEvent(event)
