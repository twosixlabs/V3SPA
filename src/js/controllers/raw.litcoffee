    vespaControllers = angular.module('vespaControllers')

    vespaControllers.controller 'rawCtrl', ($scope, VespaLogger,
        IDEBackend, $timeout, $modal, PositionManager, $q, SockJSService) ->

      $scope.update_view = (data) ->
        console.log "in rawCtrl $scope.update_view"
        $scope.rules = data.parameterized.rules
        $scope.xfilterRules = crossfilter $scope.rules
        console.log $scope.xfilterRules.size()

      IDEBackend.add_hook "json_changed", $scope.update_view
      $scope.$on "$destroy", ->
        IDEBackend.unhook "json_changed", $scope.update_view

      start_data = IDEBackend.get_json()
      if start_data
        $scope.update_view(start_data)