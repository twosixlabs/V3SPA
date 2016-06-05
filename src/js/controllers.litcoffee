    vespaControllers = angular.module('vespaControllers', 
        ['ui.ace', 'vespa.services', 'ui.bootstrap', 'ui.select2',
        'angularFileUpload', 'vespa.directives', 'vespaFilters'])

The main controller. avispa is a subcontroller.

    vespaControllers.controller 'ideCtrl', ($scope, $rootScope, SockJSService, VespaLogger, $modal, AsyncFileReader, IDEBackend, $timeout, RefPolicy) ->

      $scope._ = _

      $scope.view_control = 
        unused_ports: false

      $scope.$watchCollection 'view_control', (new_collection)->
        for k, v of new_collection
          do (k, v)->
            IDEBackend.set_view_control k, v

      $scope.$watchCollection 'analysis_ctrl', (new_collection)->
        for k, v of new_collection
          do (k, v)->
            IDEBackend.set_query_param k, v

      $scope.policy = IDEBackend.current_policy

      IDEBackend.add_hook 'policy_load', (info)->
          $scope.policy = IDEBackend.current_policy

      $timeout ->
        $scope.view = 'diff'

This controls our editor/controls visibility.

      $scope.resizeEditor = (direction)->
        switch direction
          when 'larger'
            $scope.editorSize += 1 if $scope.editorSize < 2
          when 'smaller'
            $scope.editorSize -= 1

      $scope.editorSize = 1

Save the current file

      $scope.save_policy = ->
        IDEBackend.save_policy()

This function makes sure that a Reference Policy
has been loaded before calling the function
`open_modal`. It does so by opening the
reference policy load modal first if it has
not been loaded.

      ensure_refpolicy = (open_modal)->
        if RefPolicy.loading?
          RefPolicy.loading.then (policy)->
            open_modal(policy)

        else if RefPolicy.current?
          open_modal(RefPolicy.current)

        else
          # Load a reference policy
          instance = $modal.open
              templateUrl: 'refpolicyModal.html'
              controller: 'modal.refpolicy'

          instance.result.then (promise)->
              if promise
                  promise.then (refpol)->
                    if refpol
                      # When the refpolicy has actually been loaded,
                      # open the upload modal.
                      open_modal(refpol)

Create a modal for opening a policy

      $scope.open_policy = ->

        ensure_refpolicy (refpol)->
          IDEBackend.load_local_policy refpol

        #instance = $modal.open
        #  templateUrl: 'policyOpenModal.html'
        #  controller:  'modal.policy_open'

Modal dialog for new policy

      $scope.new_policy = ->
        ensure_refpolicy ->
          instance = $modal.open
            templateUrl: 'policyNewModal.html'
            controller: ($scope, $modalInstance)->

              $scope.policy = 
                type: 'selinux'

              $scope.load = ->
                $modalInstance.close($scope.policy)

              $scope.cancel = $modalInstance.dismiss

          instance.result.then (policy)->
              IDEBackend.new_policy
                id: policy.name
                type: policy.type
                refpolicy_id: RefPolicy.current._id


Create a modal for uploading policies. First we check if a reference policy
is loaded. If it is, then we open the upload modal. Otherwise we open the
RefpolicyLoad modal first, then open the file upload modal.

      $scope.upload_policy = ->

First we define the load modal function so we can call it conditionally later

        ensure_refpolicy ->

          instance = $modal.open
            templateUrl: 'policyLoadModal.html'
            controller: 'modal.policy_load'

If we get given files, read them as text and send them over the websocket

          instance.result.then(
            (inputs)-> 
              console.log(inputs)

              filelist = inputs.files

              AsyncFileReader.read filelist, (files)->
                req = 
                  domain: 'policy'
                  request: 'create'
                  payload: 
                    refpolicy_id: RefPolicy.current._id
                    documents: {}
                    type: 'selinux'

                for file, text of files
                  do (file, text)->
                    req.payload.documents[file] = 
                      text: text
                      editable: false

                SockJSService.send req, (result)->
                  if result.error
                    $.growl {title: 'Failed to upload module', message: result.payload}, 
                      type: 'danger'
                    console.log result
                  else
                    $.growl {title: 'Uploaded new module', message: result.payload.id}, 
                      type: 'success'

            ()->
              console.log("Modal dismissed")
          )


The console controller is very simple. It simply binds it's errors
scope to the VespaLogger scope

    vespaControllers.controller 'consoleCtrl', ($scope, VespaLogger) ->

      $scope.errors = VespaLogger.messages

      $scope.errorClass = (error, prepend)->
        switch error.level
          when 'error' then return "#{prepend}danger"
          when 'info' then return "#{prepend}default"
          when 'warning' then return "#{prepend}warning"
