    vespaControllers = angular.module('vespaControllers')

    vespaControllers.controller 'rawCtrl', ($scope, VespaLogger,
        IDEBackend, $timeout, $modal, PositionManager, $q, SockJSService) ->

      # Call service to get the raw SELinux policy data

      req =
        domain: 'raw'
        request: 'get'
        payload:
          filename: "apache.te"
          policy: "@current_policy._id"
          text: "@current_policy.documents.dsl.text"
          params: 'path_params.join("&")'
          hide_unused_ports: false


      SockJSService.send req, (result)=>
        if result.error  # Service error

          $.growl(
            title: "Error"
            message: result.payload
          ,
            type: 'danger'
          )

        else  # valid response. Must parse
          $.growl
              title: "Loaded"
              message: "Loaded raw policy"

          $scope.parse_data result.payload

      $scope.parse_data = (data) ->
        $scope.current_policy =
          json: null

        $scope.current_policy.json = JSON.parse data
        
        crossfilter $scope.current_policy.rules