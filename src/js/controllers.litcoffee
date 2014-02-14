    vespaControllers = angular.module('vespaControllers', 
        ['ui.ace', 'vespa.services', 'ui.bootstrap', 'ui.select2'])

The main controller. avispa is a subcontroller.

    vespaControllers.controller 'ideCtrl', ($scope, $rootScope, SockJSService, VespaLogger, $modal, AsyncFileReader, IDEBackend, $timeout, $location) ->

      $scope.policy = IDEBackend.current_policy

      $timeout ->
        $scope.view = 'dsl'
        $scope.visualizer_type = 'avispa'

      $scope.policySelectOpts = 
        query: (query)->
          req = 
            domain: 'policy'
            request: 'find'
            payload:
              selection: 
                id: true

          SockJSService.send req, (data)->
            dropdown = 
              results:  for d in data.payload
                id: d._id.$oid
                text: d.id
                data: d
                disabled: d._id.$oid == $scope.policy._id?.$oid

            query.callback(dropdown)


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
          lobsterSession.setValue contents

        IDEBackend.add_hook 'validate_error', (errors)->
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

Load a policy from the server

      $scope.load_policy = ->
        if not $scope.policySelected?
          return

        $scope.loading = true
        promise = IDEBackend.load_policy $scope.policySelected.data._id

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

        $scope.view = 'dsl'

Create a modal for uploading policies

      $scope.new_policy = ->
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
