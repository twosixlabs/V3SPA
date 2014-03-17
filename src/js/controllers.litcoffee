    vespaControllers = angular.module('vespaControllers', 
        ['ui.ace', 'vespa.services', 'ui.bootstrap', 'ui.select2',
        'angularFileUpload', 'vespa.directives'])

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

        $scope.editor_markers = []

        IDEBackend.add_hook 'validation', (annotations)->
          format_error = (err)->
            ret = 
              row: err.line - 1
              column: err.column
              type: 'error'
              text: err.message

          lobsterSession.setAnnotations _.map(annotations?.errors, (e)->
            format_error(e)
          )

          ace_range = ace.require("ace/range")

          _.filter $scope.editor_markers, (elem)->
            $scope.editor.getSession().removeMarker(elem)
            return false

          # highlight for e in annotations.highlighter
          _.each annotations.highlights, (hl)->
            range = new ace_range.Range(
              hl.range.start.row,
              hl.range.start.column,
              hl.range.end.row,
              hl.range.end.column
            )

            if hl.apply_to == 'lobster'
              session = lobsterSession
            else
              session = applicationSession

            marker = session.addMarker(
              range,
              "#{hl.type}_marker",
              "text"
            )

            $scope.editor_markers.push marker

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

Save the current file

      $scope.save_policy = ->
        IDEBackend.save_policy()

Create a modal for opening a policy

      $scope.open_policy = ->
        instance = $modal.open
          templateUrl: 'policyOpenModal.html'
          controller:  'modal.policy_open'

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
                  refpolicy_id: inputs.refpolicy.data._id
                  files: files
                  type: 'selinux'

              SockJSService.send req, (result)->
                if result.error
                  $.growl {title: 'Failed to upload module', message: result.payload}, 
                    type: 'danger'
                  console.log result

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
