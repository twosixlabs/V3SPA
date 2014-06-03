    vespaControllers = angular.module('vespaControllers') 

    vespaControllers.controller 'navCtrl', ($scope, RefPolicy, VespaLogger, SockJSService, $modal, IDEBackend)->

        policy = RefPolicy.promise()
        policy.then (policy)->
          $scope.refpolicy = policy

        $scope.load_refpolicy = ->
          instance = $modal.open
              templateUrl: 'refpolicyModal.html'
              controller: 'modal.refpolicy'

          instance.result.then (policy)->
              RefPolicy.load(policy.id).then (policy)->
                $scope.refpolicy = policy
                IDEBackend.load_local_policy policy


        $scope.status = SockJSService.status
        $scope.have_outstanding = ->
          if SockJSService.status.outstanding > 0 then true else false

