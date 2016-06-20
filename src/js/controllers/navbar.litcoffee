    vespaControllers = angular.module('vespaControllers') 

    vespaControllers.controller 'navCtrl', ($scope, RefPolicy, VespaLogger, SockJSService, $modal, IDEBackend, $location)->

        #policy = RefPolicy.promise()
        #policy.then (policy)->
        #  $scope.refpolicy = policy

        $scope.visualizer_type = 'explore'

        $scope.$watch 'visualizer_type', (value)->
          if value == 'avispa'
            $location.path('/avispa')
          else if value =='hive'
            $location.path('/hive')
          else if value =='tl_explore'
            $location.path('/tl_explore')
          else if value =='module_browser'
            $location.path('/module_browser')
          else if value =='diff'
            $location.path('/diff')
          else if value =='explore'
            $location.path('/explore')
          else
            console.error("Invalid visualizer type")

        $scope.load_refpolicy = ->
          instance = $modal.open
              templateUrl: 'refpolicyModal.html'
              controller: 'modal.refpolicy'

          instance.result.then (policy)->
              if policy != null
                $scope.refpolicy = policy
                IDEBackend.load_local_policy policy
              else #deleted
                IDEBackend.clear_policy()



        $scope.status = SockJSService.status
        $scope.have_outstanding = ->
          if SockJSService.status.outstanding > 0 then true else false

