    vespaControllers = angular.module('vespaControllers') 

    vespaControllers.controller 'modal.policy_load', (
        $scope, $modalInstance, RefPolicy, $fileUploader, AsyncFileReader) ->

            $scope.input = 
              refpolicy: null

            $scope.fileerrors = null

            $scope.uploading = 
              status: false
              name: null

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

              inputs = 
                label: $scope.input.label
                policy_file: $('#policyFile')[0].files[0]
                lobster_file:  $('#lobsterFile')[0].files[0]

              $modalInstance.close(inputs)

            $scope.cancel = ->
              $modalInstance.dismiss('cancel')

    vespaControllers.controller 'modal.policy_open', ($scope, $modalInstance) ->

            $scope.selection = 
              value: null

            $scope.cancel = $modalInstance.dismiss

            $scope.policySelectOpts = 
              query: (query)->
                promise = IDEBackend.list_policies()
                promise.then(
                  (policy_list)->
                    dropdown = 
                      results:  for d in policy_list
                        id: d._id.$oid
                        text: d.id
                        data: d
                        disabled: IDEBackend.isCurrent(d._id.$oid)

                    query.callback(dropdown)
                )

            scope = $scope
            $scope.load = ->
              if not scope.selection.value?
                $modalInstance.dismiss()

              $scope.loading = true
              promise = IDEBackend.load_policy $scope.selection.value.data._id

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

