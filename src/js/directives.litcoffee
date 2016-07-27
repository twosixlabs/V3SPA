    v3spa = angular.module 'vespa.directives',
        ['vespa.services', 'ui.bootstrap', 'ui.select2',
        'angularFileUpload', 'vespa.directives']

    v3spa.filter 'join', ->
        return (input, separator)->
            return input.join(separator)

    v3spa.filter 'pluck', ->
        return (input, field)->
            return _.pluck(input, field)

    v3spa.directive 'touchSpin', ->
      ret =
        restrict: 'A'
        replace: 'true'
        scope:
          spinnerVal: '=ngModel'
          startVal: '=touchSpin'
        template: """
        <div class='input-group input-group-sm bootstrap-touchspin'>
        <span class='input-group-btn'>
        <button ng-disabled='spinnerVal==1' ng-click='decrement()' class='btn btn-sm btn-default bootstrap-touchspin-down' type='button'>-</button>
        </span>
        <input class='form-control ' ng-model='spinnerVal' />
        <span class='input-group-btn'>
        <button ng-disabled='spinnerVal == 15' ng-click='increment()' class='btn btn-sm btn-default bootstrap-touchspin-up' type='button'>+</button>
        </span>
        </div>
        """
        controller: ($scope)->

          $scope.spinnerVal = unless $scope.startVal then 0 else $scope.startVal

          $scope.increment = ()->
            if $scope.spinnerVal < 15
              $scope.spinnerVal++

          $scope.decrement = ()->
            if $scope.spinnerVal > 1
              $scope.spinnerVal--

    v3spa.directive 'autoHeight', ($window) ->
      ret =
        restrict: 'A'
        replace: false
        transclude: false
        scope:
          modifier: '@autoHeight'
          type: "@autoHeightType"
          resize_callback: '&onResize'
        controller: ($scope, $element)->
          angular.element($window).bind 'resize', ->
            $scope.$apply ->
              if not $scope.type? or $scope.type == 'percentage'
                $element.height "#{$window.innerHeight * $scope.modifier}px"
              else if $scope.type == 'offset_bottom_px'
                $element.height "#{$window.innerHeight - $scope.modifier}px"

            if $scope.resize_callback
              $scope.resize_callback()
        link: (scope, element, attrs)->
          if not attrs.autoHeightType? or attrs.autoHeightType == 'percentage'
            element.height "#{$window.innerHeight * attrs.autoHeight}px"
          else if attrs.autoHeightType == 'offset_bottom_px'
            element.height "#{$window.innerHeight - attrs.autoHeight}px"
          scope.resize_callback()

      return ret

    v3spa.directive 'spinnerIcon', ->
      ret =
        restrict: 'A'
        replace: true
        transclude: true
        scope: 
          loading: '= spinnerIcon'
          opts: '= opts'
        template:  """
          <div>
            <div class='spinner-container' ng-show='loading'></div>
            <div ng-hide='loading'></div>
          </div>
          """
        link: (scope, element, attrs) ->
          spinner = new Spinner(scope.opts).spin()
          container = element.find('.spinner-container')[0]
          container.appendChild(spinner.el)

      return ret

    v3spa.directive 'fileUploadDrop', ->
      dir = 
        restrict: 'A'
        scope: 
          on_drop: '&fileUploadDrop'
        link: (scope, elem)->
          elem.bind 'drop', (e)->
              dataTrans = e.dataTransfer
              dataTrans ?= e.originalEvent.dataTransfer

              e.preventDefault()
              e.stopPropagation()

              elem.removeClass('file-drop-over')
              method = scope.on_drop()
              method(dataTrans.files[0], elem.attr('name'))

          elem.bind 'dragover', (e)->

            dataTrans = event.dataTransfer
            dataTrans ?= event.originalEvent.dataTransfer

            e.preventDefault()
            e.stopPropagation()

            elem.addClass('file-drop-over')
            dataTrans.dropEffect = 'copy'

          elem.bind 'dragleave', (e)->
            e.preventDefault()
            e.stopPropagation()

            elem.removeClass('file-drop-over')

      return dir

    v3spa.directive 'editor', ['IDEBackend', 'RefPolicy', '$modal', (IDEBackend, RefPolicy, $modal) ->
      ret =
        restrict: 'E'
        replace: true
        transclude: true
        templateUrl: 'partials/editor.html'
        link:
          pre: (scope, element, attrs) ->
            # Assumes ideCtrl is the parent controller

            scope.policy = IDEBackend.current_policy

            IDEBackend.add_hook 'policy_load', (info)->
              scope.policy = IDEBackend.current_policy

            scope.$watch 'raw_view_selection', (newv, oldv)->
              if newv
                m = $modal.open
                  templateUrl: 'moduleViewModal.html'
                  controller: 'modal.view_module'
                  windowClass: 'super-large-modal'
                  resolve:
                    documents: ->
                      RefPolicy.fetch_module_files(newv.id)
                    module: ->
                      newv
                  size: 'lg'

                m.result.finally ->
                  scope.raw_view_selection = null

            scope.raw_module_select2 =
              data: ->
                  unless scope.policy?.modules
                    retval =
                      results: []
                  else 
                    retval = 
                        results: _.map scope.policy.modules, (v, k)->
                            ret = 
                              text: k
                              id: k

      return ret
      ]

    v3spa.directive 'moduleBrowserControls', ->
      ret =
        restrict: 'E'
        replace: true
        template: """
                  <div class="row">
                    <div class="form-group">
                      <label class="control-label pad-right">Controls</label>
                      <div class="btn-group" role="group">
                        <button ng-click="collapse('collapse-all')" type="button" class="btn btn-sm btn-default">Collapse all</button>
                        <button ng-click="collapse('open-all')" type="button" class="btn btn-sm btn-default">Open all</button>
                      </div>
                    </div>
                  </div>
                  """
      return ret

    v3spa.directive 'modulesListInput', ->
      ret =
        restrict: 'E'
        replace: true
        scope:
          module: '='
          moduleClick: '&'
        template: '<input type="checkbox" ng-model="module.selected" ng-change="moduleClick()">'
        link: (scope, element, attrs) ->
          scope.$watch 'module.indeterminate', (newVal, oldVal) ->
            if newVal == true
              $(element).prop('indeterminate', true)
            else if newVal == false
              $(element).prop('indeterminate', false)
      return ret

    v3spa.directive 'changedNodes', ->
      ret =
        restrict: 'E'
        replace: true
        scope:
          policyIds: '='
          nodes: '='
          title: '@'
          selectionChange: '&'
        templateUrl: 'partials/diff_controls.html'
        link: (scope, element, attrs) ->
          deregistrationArr = []
          scope.allChecked =
            primary: false,
            both: false,
            comparison: false

          setupNodeWatch = (nodeList, policy) ->
            scope.$watch(
              ((scope) ->
                nodeList.map (n) -> n.selected
              ),
              ((newVal, oldVal) ->
                scope.allChecked[policy] = newVal.reduce ((prevVal, currSelected) -> prevVal && currSelected), true
              ), true)

          update = (newVal, oldVal) ->
            deregistration() while (deregistration = deregistrationArr.pop())

            scope.allChecked =
              primary: false,
              both: false,
              comparison: false

            scope.primaryNodes = scope.nodes.filter (n) -> n.policy == scope.policyIds.primary
            scope.bothNodes = scope.nodes.filter (n) -> n.policy == scope.policyIds.both
            scope.comparisonNodes = scope.nodes.filter (n) -> n.policy == scope.policyIds.comparison

            deregistrationArr.push setupNodeWatch(scope.primaryNodes, "primary")
            deregistrationArr.push setupNodeWatch(scope.bothNodes, "both")
            deregistrationArr.push setupNodeWatch(scope.comparisonNodes, "comparison")
          
          scope.$watch 'nodes', update
          scope.$watch 'policyIds', update

          scope.selectAll = (policyId) ->
            if policyId == scope.policyIds.primary
              nodes = scope.primaryNodes
              scope.allChecked['primary'] = true
            else if policyId == scope.policyIds.both
              nodes = scope.bothNodes
              scope.allChecked['both'] = true
            else
              scope.allChecked['comparison'] = true
              nodes = scope.comparisonNodes
            nodes.forEach (n) ->
              n.selected = true
            scope.selectionChange()

          scope.selectNone = (policyId) ->
            if policyId == scope.policyIds.primary
              scope.allChecked['primary'] = false
              nodes = scope.primaryNodes
            else if policyId == scope.policyIds.both
              scope.allChecked['both'] = false
              nodes = scope.bothNodes
            else
              scope.allChecked['comparison'] = false
              nodes = scope.comparisonNodes
            nodes.forEach (n) ->
              n.selected = false
            scope.selectionChange()

      return ret

    v3spa.directive 'avFilter', ->
      ret =
        restrict: 'E'
        replace: true
        scope:
          items: '='
          title: '@'
          selectionChange: '&'
        templateUrl: 'partials/av_filters.html'
        link: (scope, element, attrs) ->
          deregistration = null
          scope.allChecked = false

          setupNodeWatch = (itemList) ->
            scope.$watch(
              ((scope) ->
                itemList.map (n) -> n.selected
              ),
              ((newVal, oldVal) ->
                scope.allChecked = newVal.reduce ((prevVal, currSelected) -> prevVal && currSelected), true
              ), true)

          update = (newVal, oldVal) ->
            if deregistration then deregistration()

            scope.allChecked =
              primary: false,
              both: false,
              comparison: false

            deregistration = setupNodeWatch(scope.items)
          
          scope.$watch 'items', update

          scope.selectAll = () ->
            scope.allChecked = true
            scope.items.forEach (n) ->
              n.selected = true
            scope.selectionChange()

          scope.selectNone = () ->
            scope.allChecked = false
            scope.items.forEach (n) ->
              n.selected = false
            scope.selectionChange()

      return ret

    v3spa.directive 'rangeSlider', ->
      ret =
        restrict: 'E'
        replace: true
        scope:
          width: '@'
          height: '@'
          range: '='
          rangeChange: '&'
          rangeChangeStart: '&'
          rangeChangeEnd: '&'
          round: '@'
        template: """
                  <div class="range-slider"></div>
                  """
        link: (scope, element, attrs) ->
          margin =
            top: 5
            bottom: 20
          height = (scope.height or 50) - margin.top - margin.bottom
          margin.right = height/2 + 3 + 40 # handle + padding + approx text width
          margin.left = margin.right

          width = (scope.width or 500) - margin.left - margin.right

          updateHandleValues = () ->
            handleFormat = x.tickFormat()
            brushg.selectAll(".resize text")
              .text((d,i) ->
                extent = brush.extent()
                if attrs.round then extent = roundExtent(extent)
                handleFormat(if i then extent[0] else extent[1])
              )

          x = d3.scale.linear()
            .domain(scope.range)
            .range([0, width])

          brush = d3.svg.brush()
            .x(x)
            .extent(scope.range)

          roundExtent = (extent) ->
            newExtent = [Math.round(brush.extent()[0]), Math.round(brush.extent()[1])]
            if newExtent[0] >= newExtent[1]
              newExtent = [Math.floor(brush.extent()[0]), Math.ceil(brush.extent()[1])]
            return newExtent

          brush.on("brush.updatehandles", updateHandleValues)

          if attrs.rangeChange
            brush.on("brush.callback", () ->
              if attrs.round then brush.extent(roundExtent(brush.extent()))
              scope.rangeChange({extent: brush.extent()}))
          if attrs.rangeChangeStart
            brush.on("brushstart.callback", () ->
              if attrs.round then brush.extent(roundExtent(brush.extent()))
              scope.rangeChangeStart({extent: brush.extent()}))
          if attrs.rangeChangeEnd
            brush.on("brushend.callback", () ->
              if attrs.round then brush.extent(roundExtent(brush.extent()))
              scope.rangeChangeEnd({extent: brush.extent()}))

          brushAxis = d3.svg.axis()
            .scale(x)
            .orient("bottom")
            .tickValues(scope.range)
            .tickSize(0,4)
            .tickPadding(5)

          arc = d3.svg.arc()
            .outerRadius(height/2)
            .startAngle(0)
            .endAngle((d,i) -> if i then -Math.PI else Math.PI)

          svg = d3.select(element[0]).append("svg")
            .attr("width", width + margin.left + margin.right)
            .attr("height", height + margin.top + margin.bottom)
            .style("margin", "0 0 14px 0")
            .append("g")
            .attr("transform", "translate(" + margin.left + "," + margin.top + ")")

          axisg = svg.append("g")
            .attr("class", "x axis")
            .attr("transform", "translate(0," + height + ")")
          
          axisg.call(brushAxis)

          brushg = svg.append("g")
            .attr("class", "brush")
            .call(brush)

          brushg.selectAll(".resize").append("path")
            .attr("transform", "translate(0," + height/2 + ")")
            .attr("d", arc)

          brushg.selectAll(".resize").append("text")
            .attr("transform", (d,i) -> "translate(" + (if i then -1 else 1) * (height/2+3) + "," + height/2 + ")")
            .attr("dy", "0.35em")
            .attr("text-anchor", (d,i) -> if i then "end" else "start")
            .attr("pointer-events", "none")
            .style("fill", "#888")

          # Add the handle values text
          updateHandleValues()

          brushg.selectAll("rect")
            .attr("height", height)

          scope.$watch 'range', (newVal, oldVal) ->
            if newVal
              x.domain newVal
              brushAxis.tickValues newVal
              axisg.call brushAxis
              brush.extent newVal
              updateHandleValues()

      return ret

Sigma tooltips for nodes in the condensed graph format.

    v3spa.directive 'condensedTooltip', () ->
      ret =
        restrict: 'E'
        replace: true
        scope:
          node: '='
          alternateNodes: '='
          showNeighbors: '&'
          addToAlwaysVisibleList: '&'
          removeFromAlwaysVisibleList: '&'
          isAlwaysVisible: '@'
          sigma: '='
          statistics: '='
          authorityFormatter: '='
          hubFormatter: '='
        template: """
          <div>
            <div class="sigma-tooltip-header" title="{{node.label}}">{{node.label}}</div>
            <div class="sigma-tooltip-body">
              <button
                      type="button"
                      class="btn btn-default btn-xs btn-block"
                      ng-if="connections > 0"
                      ng-click='showNeighbors({node:node})'
                      >
                Add <strong>{{connections}} {{connections !== 1 ? 'neighbors' : 'neighbor'}}</strong> to always visible list
              </button>
              <button
                      type="button"
                      class="btn btn-default btn-xs btn-block"
                      ng-if="visible"
                      ng-click='removeFromAlwaysVisibleList({node:node})'
                      >
                Remove <strong>this node</strong> from always visible list
              </button>
              <button
                      type="button"
                      class="btn btn-default btn-xs btn-block"
                      ng-if="!visible"
                      ng-click='addToAlwaysVisibleList({nodes:node})'
                      >
                Add <strong>this node</strong> to always visible list
              </button>
              <div ng-if="alternateNodes.length > 0" style="margin-top: 10px;">
                This type is also {{isSubject ? 'an object' : 'a subject'}}.
                <button
                        type="button"
                        class="btn btn-default btn-xs btn-block"
                        ng-click='addToAlwaysVisibleList({nodes:alternateNodes})'
                        >
                  Add <strong>{{alternateNodes.length}}
                  {{isSubject ? 'object' : 'subject'}}
                  {{alternateNodes.length > 1 ? 'nodes' : 'node'}}</strong>
                  to always visible list
                </button>
              </div>
            </div>
            <div class="sigma-tooltip-footer">
              <div><span class="stats-label">Connections:</span> <strong>{{connections}}</strong></div>
              <div><span class="stats-label">Authority:</span> <strong>{{authority}}</strong></div>
              <div><span class="stats-label">Hub:</span> <strong>{{hub}}</strong></div>
            </div>
          </div>
          """
        link: (scope, element, attrs) ->
          scope.visible = scope.$eval(attrs.isAlwaysVisible)
          scope.connections = scope.sigma.graph.degree(scope.node.id)
          scope.authority = if scope.statistics[scope.node.id] then scope.authorityFormatter(scope.statistics[scope.node.id].authority) else 'n/a'
          scope.hub = if scope.statistics[scope.node.id] then scope.hubFormatter(scope.statistics[scope.node.id].hub) else 'n/a'
          scope.isSubject = scope.node.id.indexOf('.') == -1

          # Verify that the template has updated and resolved the {{expressions}}
          if !scope.$$phase then scope.$apply()

      return ret

Sigma tooltips for nodes in the Lobster condensed graph format.

    v3spa.directive 'condensedLobsterTooltip', () ->
      ret =
        restrict: 'E'
        replace: true
        scope:
          node: '='
          alternateNodes: '='
          showNeighbors: '&'
          addToAlwaysVisibleList: '&'
          removeFromAlwaysVisibleList: '&'
          isAlwaysVisible: '@'
          sigma: '='
          statistics: '='
          authorityFormatter: '='
          hubFormatter: '='
        template: """
          <div>
            <div class="sigma-tooltip-header" title="{{node.label}}">{{node.label}}</div>
            <div class="sigma-tooltip-body">
              <button
                      type="button"
                      class="btn btn-default btn-xs btn-block"
                      ng-if="connections > 0"
                      ng-click='showNeighbors({node:node})'
                      >
                Add <strong>{{connections}} {{connections !== 1 ? 'neighbors' : 'neighbor'}}</strong> to always visible list
              </button>
              <button
                      type="button"
                      class="btn btn-default btn-xs btn-block"
                      ng-if="visible"
                      ng-click='removeFromAlwaysVisibleList({node:node})'
                      >
                Remove <strong>this node</strong> from always visible list
              </button>
              <button
                      type="button"
                      class="btn btn-default btn-xs btn-block"
                      ng-if="!visible"
                      ng-click='addToAlwaysVisibleList({nodes:node})'
                      >
                Add <strong>this node</strong> to always visible list
              </button>
              <div ng-if="alternateNodes.length > 0" style="margin-top: 10px;">
                This type is also {{isSubject ? 'an object' : 'a subject'}}.
                <button
                        type="button"
                        class="btn btn-default btn-xs btn-block"
                        ng-click='addToAlwaysVisibleList({nodes:alternateNodes})'
                        >
                  Add <strong>{{alternateNodes.length}}
                  {{isSubject ? 'object' : 'subject'}}
                  {{alternateNodes.length > 1 ? 'nodes' : 'node'}}</strong>
                  to always visible list
                </button>
              </div>
            </div>
            <div class="sigma-tooltip-footer">
              <div><span class="stats-label">Connections:</span> <strong>{{connections}}</strong></div>
              <div><span class="stats-label">Authority:</span> <strong>{{authority}}</strong></div>
              <div><span class="stats-label">Hub:</span> <strong>{{hub}}</strong></div>
              <div><span class="stats-label">Module:</span> <strong>{{node.module}}</strong></div>
            </div>
          </div>
          """
        link: (scope, element, attrs) ->
          scope.visible = scope.$eval(attrs.isAlwaysVisible)
          scope.connections = scope.sigma.graph.degree(scope.node.id)
          scope.authority = if scope.statistics[scope.node.id] then scope.authorityFormatter(scope.statistics[scope.node.id].authority) else 'n/a'
          scope.hub = if scope.statistics[scope.node.id] then scope.hubFormatter(scope.statistics[scope.node.id].hub) else 'n/a'
          scope.isSubject = scope.node.id.indexOf('.') == -1

          # Verify that the template has updated and resolved the {{expressions}}
          if !scope.$$phase then scope.$apply()

      return ret