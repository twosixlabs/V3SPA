    vespaControllers = angular.module('vespaControllers') 

    vespaControllers.controller 'navCtrl', ($scope, RefPolicy, VespaLogger, SockJSService, $modal, IDEBackend, $location)->

        #policy = RefPolicy.promise()
        #policy.then (policy)->
        #  $scope.refpolicy = policy

        $scope.getCurrentPolicy = () ->
          $scope.policy = IDEBackend.current_policy

          supported_docs = $scope.policy.supported_docs

          if supported_docs.raw and not supported_docs.dsl
            $scope.visualizer_type = 'explore'
          else if not supported_docs.raw and supported_docs.dsl
            $scope.visualizer_type = 'module_browser'

        $scope.getCurrentPolicy()

        $scope.visualizer_type = 'explore'

        $scope.$watch 'visualizer_type', (value)->
          if value =='module_browser'
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


        IDEBackend.add_hook "policy_load", $scope.getCurrentPolicy
        
        $scope.$on "$destroy", ->
          IDEBackend.unhook "policy_load", $scope.getCurrentPolicy

