    vespaControllers = angular.module('vespaControllers') 

    vespaControllers.controller 'modal.policy_load', (
        $scope, $modalInstance, RefPolicy, $fileUploader) ->

            $scope.input = 
              refpolicy: null
              files: {}

            $scope.invalid = ->
              return not $scope.input.files.te?
            $scope.add_file_input = (file, input_name)->
              $scope.$apply ->
                $scope.input.files[input_name] = file

            $scope.load = ->
              $modalInstance.close($scope.input)

            $scope.cancel = ->
              $modalInstance.dismiss('cancel')

    vespaControllers.controller 'modal.policy_open', (
      $scope, $modalInstance, RefPolicy, IDEBackend) ->

            $scope.selection = 
                refpolicy: RefPolicy.current_as_select2()

Watcher to make sure the reference policy modules get listed
when the reference policy is selected.

            $scope.modules = null
            $scope.$watch( 
              ->
                $scope.selection.refpolicy
            ,
              (newv, oldv)->
                if newv?
                  promise = RefPolicy.list_modules(newv.id)
                  promise.then (data)->
                    $scope.modules = data[0].modules
            )

            $scope.cancel = $modalInstance.dismiss

Loader for the reference policy dropdown

            $scope.policySelectOpts = 
              query: (query)->
                promise = RefPolicy.list()
                promise.then(
                  (policy_list)->
                    dropdown = 
                      results:  for d in policy_list
                        id: d._id.$oid
                        text: d.id
                        data: d
                        disabled: IDEBackend.current_policy.refpolicy_id == d._id.$oid

                    query.callback(dropdown)
                )

Load the clicked on policy into the IDE.

            $scope.load = (name)->
              if not $scope.selection.refpolicy?
                $modalInstance.dismiss()

              $scope.loading = true

              promise = IDEBackend.load_policy $scope.selection.refpolicy.id, name

              promise.then(
                (data)->
                  console.log "Loaded policy successfully"
                  $scope.loading = false
              ,
                (error)->
                  $.growl "Failed to load policy", 
                    type: 'warning'
                  console.log "Policy load failed: #{error}"
                  $scope.loading = false
              )

              $modalInstance.close() 

