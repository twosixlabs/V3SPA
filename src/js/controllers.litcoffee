    vespaControllers = angular.module('vespaControllers', 
        ['ui.ace', 'vespa.services', 'ui.bootstrap', 'ui.select2',
        'angularFileUpload', 'vespa.directives'])

The main controller. avispa is a subcontroller.

    vespaControllers.controller 'ideCtrl', ($scope, $rootScope, SockJSService, VespaLogger, $modal, AsyncFileReader, IDEBackend, $timeout, $location, RefPolicy) ->

      $scope._ = _

      $scope.qparams = null
      $scope.$watch 'qparams', (newv)->
          IDEBackend.queryparams = newv

      $scope.policy = IDEBackend.current_policy

      IDEBackend.add_hook 'policy_load', (info)->
        $timeout ->
          $scope.policy = IDEBackend.current_policy

          $scope.editorSessions = {}
          for nm, doc of $scope.policy.documents
            do (nm, doc)->
              mode = if doc.mode then doc.mode else 'text'
              session = new ace.EditSession doc.text, "ace/mode/#{mode}"

              session.on 'change', (text)->
                IDEBackend.update_document nm, session.getValue(), 

              session.selection.on 'changeSelection', (e, sel)->
                IDEBackend.highlight_selection nm, sel.getRange()

              $scope.editorSessions[nm] = 
                session: session


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

        $scope.editorSessions = {}
        for nm, doc of $scope.policy.documents
          do (nm, doc)->
            mode = if doc.mode then doc.mode else 'text'
            session = new ace.EditSession doc.text, "ace/mode/#{mode}"

            session.on 'change', (text)->
              IDEBackend.update_document nm, session.getValue()

            $scope.editorSessions[nm] = 
              session: session


        IDEBackend.add_hook 'doc_changed', (doc, contents)->
          $timeout(
            ->
              $scope.editorSessions[doc].session.setValue contents
          , 2)


        $scope.editor_markers = []

        IDEBackend.add_hook 'validation', (annotations)->
          dsl_session = $scope.editorSessions.dsl.session

          format_error = (err)->
            pos = err.srcloc
            unless pos.start?
              lastRow = dsl_session.getLength()
              while _.isEmpty(toks = dsl_session.getTokens(lastRow))
                lastRow--

              pos = 
                start:
                  line: lastRow + 1
                  col: 1
                end:
                  line: lastRow + 1
                  col: dsl_session.getLine(lastRow).length + 1

            annotations.highlights ?= []
            annotations.highlights.push 
              range:  pos
              apply_to: 'dsl'
              type: 'error'

            ret = 
              row: lastRow
              column: pos.start.col
              type: 'error'
              text: "#{err.filename}: #{err.message}"

          $timeout ->
            session = $scope.editorSessions.dsl.session
            session.setAnnotations _.map(annotations?.errors, (e)->
              format_error(e)
            )

          ace_range = ace.require("ace/range")

          _.filter $scope.editor_markers, (elem)->
            $scope.editor.getSession().removeMarker(elem)
            return false

          $timeout ->
            # highlight for e in annotations.highlighter
            _.each annotations.highlights, (hl)->
              return unless hl?

              range = new ace_range.Range(
                hl.range.start.line - 1,
                hl.range.start.col - 1,
                hl.range.end.line - 1,
                hl.range.end.col - 1
              )

              session = $scope.editorSessions[hl.apply_to]?.session

              if not session?  # Just bail
                return

              marker = session.addMarker(
                range,
                "#{hl.type}_marker",
                "text"
              )

              $scope.editor_markers.push marker

Watch the view control and switch the editor session

        $scope.setEditorTab = (name)->
          $timeout ->
            sessInfo = $scope.editorSessions[name]

            if sessInfo.tab? and not _.isEmpty sessInfo.tab
              prevIndex = sessInfo.tab.css('z-index')

            idx = 0
            for nm, info of $scope.editorSessions
              idx++
              if not info.tab? or _.isEmpty info.tab
                info.tab = angular.element "#editor_tabs \#tab_#{nm}"

              if nm == name
                info.tab.css 'z-index', 4
              else
                if prevIndex?
                  nowindex = info.tab.css('z-index')
                  if nowindex > prevIndex
                    info.tab.css 'z-index', nowindex - 1
                else
                  info.tab.css 'z-index', _.size($scope.editorSessions) - idx


            editor.setSession(sessInfo.session)

            if $scope.policy.documents[name].editable == false
              editor.setOptions
                readOnly: true
                highlightActiveLine: false
                highlightGutterLine: false
              editor.renderer.$cursorLayer.element.style.opacity=0
            else
              editor.setOptions
                readOnly: false
                highlightActiveLine: true
                highlightGutterLine: true
              editor.renderer.$cursorLayer.element.style.opacity=1

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

This function makes sure that a Reference Policy
has been loaded before calling the function
`open_modal`. It does so by opening the
reference policy load modal first if it has
not been loaded.

      ensure_refpolicy = (open_modal)->
        if RefPolicy.loading?
          RefPolicy.loading.then ->
            open_modal()

        else if RefPolicy.current?
          open_modal()

        else
          # Load a reference policy
          instance = $modal.open
              templateUrl: 'refpolicyModal.html'
              controller: 'modal.refpolicy'

          instance.result.then (policy)->
              RefPolicy.load(policy.id).then (policy)->
                # When the refpolicy has actually been loaded,
                # open the upload modal.
                open_modal()

Create a modal for opening a policy

      $scope.open_policy = ->

        ensure_refpolicy ->
          instance = $modal.open
            templateUrl: 'policyOpenModal.html'
            controller:  'modal.policy_open'

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
