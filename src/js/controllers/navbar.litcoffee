    vespaControllers = angular.module('vespaControllers') 

    vespaControllers.controller 'navCtrl', ($scope, RefPolicy, VespaLogger, SockJSService, $modal, IDEBackend)->

        #policy = RefPolicy.promise()
        #policy.then (policy)->
        #  $scope.refpolicy = policy

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

