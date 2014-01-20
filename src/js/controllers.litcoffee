    vespaControllers = angular.module('vespaControllers', 
        ['ui.ace', 'vespa.socket', 'ui.bootstrap', 'ui.select2'])

The main controller. avispa is a subcontroller.

    vespaControllers.controller 'ideCtrl', ($scope, $rootScope, SockJSService, VespaLogger, $modal, AsyncFileReader) ->

      $scope.policy =
        application: ""
        dsl: ""
        view: 'dsl'

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
                id: d._id
                text: d.id
                disabled: d._id.$oid == $scope.policy._id?.$oid

            query.callback(dropdown)


This controls our editor visibility.

      $scope.toggleEditor = ->
        $scope.editorVisible = !$scope.editorVisible

      $scope.editorVisible = true

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
          $scope.policy.dsl = lobsterSession.getValue()
        $scope.$watch 'policy.dsl', (contents)->
          lobsterSession.setValue $scope.policy.dsl


        applicationSession.on 'change', (text)->
          $scope.policy.application = applicationSession.getValue()
        $scope.$watch 'policy.application', (contents)->
          applicationSession.setValue $scope.policy.application

Watch the view control and switch the editor session

        $scope.$watch 'policy.view', (value)->
          if value == 'dsl'
            editor.setSession(lobsterSession)
          else
            editor.setSession(applicationSession)

        editor.setSession(lobsterSession)

Ace needs a statically sized div to initialize, but we want it
to be the full page, so make it so.

        editor.resize()

Check syntax button callback

      $scope.check_lobster = ->

        req =
          domain: 'lobster'
          request: 'validate'
          payload: $scope.editor.getValue()

        $scope.loading = true

        SockJSService.send req, (result)->
          $scope.loading = false
          if result.error
            VespaLogger.log 'lobster', 'error', result.payload
          else
            $rootScope.$broadcast 'lobsterUpdate', result

Load a policy from the server

      $scope.load_policy = ->
        if not $scope.policySelected?
          return

        req = 
          domain: 'policy'
          request: 'get'
          payload: $scope.policySelected.id

        SockJSService.send req, (data)->
          data.payload.view = 'dsl'
          $scope.policy = data.payload

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
                lobster_file:  $('#policyFile')[0].files[0]

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
