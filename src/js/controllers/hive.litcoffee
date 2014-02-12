    vespaControllers = angular.module('vespaControllers')

    vespaControllers.controller 'hiveCtrl', ($scope, VespaLogger)->
      plotter = require('hive')

      $scope.$on 'lobsterUpdate', (event, data)->
        json_data = JSON.parse(data.payload)
        plotter('#surface', json_data.domain)
