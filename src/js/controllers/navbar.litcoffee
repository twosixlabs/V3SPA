    vespaControllers = angular.module('vespaControllers') 

    vespaControllers.controller 'navCtrl', ($scope, RefPolicy, VespaLogger, $modal)->

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