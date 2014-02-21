    vespaControllers = angular.module('vespaControllers')

    vespaControllers.controller 'hiveCtrl', ($scope, VespaLogger, IDEBackend, PositionManager)->
      plotter = require('hive')


      update_listener = (json_data)->

        positionMgr = PositionManager("hive.viewport::#{IDEBackend.current_policy._id}")

        if not json_data.domain?
          json_data.domain = 
            connections: []
            subdomains: []

        plotter '#surface', json_data.domain, (tooltip_html)->

          if not tooltip_html?
            $("#hivetooltip").hide()
            $("#hivetooltip").html("")
          else
            $('#hivetooltip').html(tooltip_html)
            $("#hivetooltip").show()


        svgPanZoom.init
          selector: '#surface svg'
          panEnabled: true
          zoomEnabled: true
          dragEnabled: false
          minZoom: 0.5
          maxZoom: 10
          onZoom: (scale, transform)->
            positionMgr.update transform
          onPanComplete: (coords, transform) ->
            positionMgr.update transform

        $scope.$watch(
          ->
            (positionMgr.data)
        , 
          (newv, oldv)->
            if not newv? or _.keys(newv).length == 0
              return
            g = svgPanZoom.getSVGViewport($("#surface svg")[0])
            svgPanZoom.set_transform(g, newv)
        )


      IDEBackend.add_hook 'json_changed', update_listener
      $scope.$on '$destroy', ->
        IDEBackend.unhook('json_changed', update_listener)

      start_data = IDEBackend.get_json()
      if start_data
        update_listener(start_data)
