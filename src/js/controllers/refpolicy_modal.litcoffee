    vespaControllers = angular.module('vespaControllers') 

    vespaControllers.controller 'modal.refpolicy', (
        $scope, $modalInstance, RefPolicy, AsyncFileReader) ->

            $scope.input = 
              refpolicy: RefPolicy.current_as_select2()

            $scope.fileerrors = null

            $scope.uploading = 
              status: false
              name: null

            $scope.invalid = ->
              not $scope.input.refpolicy?

            $scope.load = ->
              $modalInstance.close(RefPolicy.load($scope.input.refpolicy.id))

            $scope.cancel = ->
              $modalInstance.dismiss('cancel')

            $scope.upload_refpolicy = (file)->
              if file.type != 'application/zip' and file.type != 'application/x-zip-compressed'
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

            $scope.deleting = false

            $scope.delete = ->
              $modalInstance.close(RefPolicy.delete($scope.input.refpolicy.id))

            return null

