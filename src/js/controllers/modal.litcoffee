    vespaControllers = angular.module('vespaControllers') 

    vespaControllers.controller 'modal.policy_load', (
        $scope, $modalInstance, RefPolicy, $fileUploader, AsyncFileReader) ->

            $scope.input = 
              refpolicy: null
              files: {}

            $scope.invalid = ->
              return not ($scope.input.refpolicy? and 
                          $scope.input.files.te?)

            $scope.fileerrors = null

            $scope.uploading = 
              status: false
              name: null

            $scope.add_file_input = (file, input_name)->
              $scope.$apply ->
                $scope.input.files[input_name] = file

            $scope.upload_refpolicy = (file)->
              if file.type != 'application/zip'
                $scope.$apply ->
                  $scope.fileerrors = "Reference policy must be uploaded as a zipfile"
                console.log($scope.fileerrors)

              else
                $scope.$apply ->
                  $scope.uploading.status = 1
                  $scope.uploading.name = file.name
                  $scope.fileerrors = null

                AsyncFileReader.read_binary_chunks file, (chunk, start, len, total)->
                  uploading = RefPolicy.upload_chunk file.name, chunk, start, len, total

                  uploading.then(
                    (status)->
                      console.log status.progress
                      $scope.uploading.status = status.progress * 100.0

                      if status.progress >= 1
                        $scope.uploading.status = false
                        $scope.input.refpolicy = 
                            id: status.info._id.$oid
                            text: status.info.id
                            data: status.info
                  ,
                    (error)->
                      AsyncFileReader.have_error = true
                      $scope.fileerrors = error
                      $scope.uploading.status = false
                      $scope.uploading.name = null
                  )

                  return uploading

            $scope.list_refpolicies = 
              query: (query)->
                promise = RefPolicy.list()
                promise.then(
                  (policy_list)->
                    dropdown = 
                      results:  for d in policy_list
                        id: d._id.$oid
                        text: d.id
                        data: d

                    query.callback(dropdown)
                )

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
                        disabled: IDEBackend.current_policy._id == d._id.$oid

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

