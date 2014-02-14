    vespaControllers = angular.module('vespaControllers', 
        ['ui.ace', 'vespa.services', 'ui.bootstrap', 'ui.select2'])

The main controller. avispa is a subcontroller.

    vespaControllers.controller 'ideCtrl', ($scope, $rootScope, SockJSService, VespaLogger, $modal, AsyncFileReader, IDEBackend, $timeout, $location) ->

      $scope.policy = IDEBackend.current_policy

      IDEBackend.add_hook 'policy_load', (info)->
        $timeout ->
          $scope.policy = IDEBackend.current_policy

      $scope.visualizer_type = 'avispa'
      $timeout ->
        $scope.view = 'dsl'


This controls our editor visibility.

      $scope.resizeEditor = (direction)->
        switch direction
          when 'larger'
            $scope.editorSize += 1 if $scope.editorSize < 2
          when 'smaller'
            $scope.editorSize -= 1

      $scope.editorSize = 1


      $scope.aceLoaded = (editor) ->
        editor.setTheme("ace/theme/solarized_light");
        editor.setKeyboardHandler("vim");
        editor.setBehavioursEnabled(true);
        editor.setSelectionStyle('line');
        editor.setHighlightActiveLine(true);
        editor.setShowInvisibles(false);
        editor.setDisplayIndentGuides(false);
        editor.renderer.setHScrollBarAlwaysVisible(false);
        editor.setAnimatedScroll(false);
        editor.renderer.setShowGutter(true);
        editor.renderer.setShowPrintMargin(false);
        editor.setHighlightSelectedWord(true);

        $scope.editor = editor

        lobsterSession = new ace.EditSession $scope.policy.dsl, 'ace/mode/lobster'
        applicationSession = new ace.EditSession $scope.policy.application, 'ace/mode/text'

Two way bind editor changing and model changing

        lobsterSession.on 'change', (text)->
          IDEBackend.update_dsl(lobsterSession.getValue())

        IDEBackend.add_hook 'dsl_changed', (contents)->
          $timeout ->
            lobsterSession.setValue contents

        IDEBackend.add_hook 'validation', (errors)->
          format_error = (err)->
            ret = 
              row: err.line - 1
              column: err.column
              type: 'error'
              text: err.message

          lobsterSession.setAnnotations ( format_error(e) for e in errors )

        IDEBackend.add_hook 'app_changed', (contents)->
          applicationSession.setValue contents

Watch the view control and switch the editor session

        $scope.$watch 'view', (value)->
          if value == 'dsl'
            editor.setSession(lobsterSession)
            editor.setReadOnly(false)
          else
            editor.setSession(applicationSession)
            editor.setReadOnly(true)

        $scope.$watch 'visualizer_type', (value)->
          if value == 'avispa'
            $location.path('/avispa')
          else if value =='hive'
            $location.path('/hive')
          else
            console.error("Invalid visualizer type")

Ace needs a statically sized div to initialize, but we want it
to be the full page, so make it so.

        editor.resize()

Check syntax button callback

      $scope.check_lobster = ->

        $scope.loading = true
        response = IDEBackend.validate_dsl()

        response.then(
          (result)->
            console.log result
            $scope.loading = false
          (error)->
            console.log error
            $scope.loading = false
        )

Create a modal for opening a policy

      $scope.open_policy = ->
        instance = $modal.open
          templateUrl: 'policyOpenModal.html'
          controller: ($scope, $modalInstance) ->

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

Modal dialog for new policy

      $scope.new_policy = ->
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

Create a modal for uploading policies

      $scope.upload_policy = ->
        instance = $modal.open
          templateUrl: 'policyLoadModal.html'
          controller: ($scope, $modalInstance) ->

            $scope.input = {}

            $scope.load = ->

              inputs = 
                label: $scope.input.label
                policy_file: $('#policyFile')[0].files[0]
                lobster_file:  $('#lobsterFile')[0].files[0]

              $modalInstance.close(inputs)

            $scope.cancel = ->
              $modalInstance.dismiss('cancel')

If we get given files, read them as text and send them over the websocket

        instance.result.then(
          (inputs)-> 
            console.log(inputs)

            filelist = 
              application: inputs.policy_file
              dsl: inputs.lobster_file

            AsyncFileReader.read filelist, (files)->
              req = 
                domain: 'policy'
                request: 'create'
                payload: 
                  id: inputs.label
                  application: files.application
                  dsl: files.dsl

              SockJSService.send(req)

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
