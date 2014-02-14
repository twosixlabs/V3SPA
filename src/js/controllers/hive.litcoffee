    vespaControllers = angular.module('vespaControllers')

    vespaControllers.controller 'hiveCtrl', ($scope, VespaLogger, IDEBackend)->
      plotter = require('hive')

      update_listener = (json_data)->

        plotter '#surface', json_data.domain, (tooltip_html)->

          if not tooltip_html?
            $("#hivetooltip").hide()
            $("#hivetooltip").html("")
          else
            $('#hivetooltip').html(tooltip_html)
            $("#hivetooltip").show()

      IDEBackend.add_hook 'json_changed', update_listener
      $scope.$on '$destroy', ->
        IDEBackend.unhook('json_changed', update_listener)

      start_data = IDEBackend.get_json()
      if start_data
        update_listener(start_data)
