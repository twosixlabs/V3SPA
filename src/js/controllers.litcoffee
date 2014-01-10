    vespaControllers = angular.module('vespaControllers', ['ui.ace'])

The main controller. avispa is a subcontroller.

    vespaControllers.controller 'ideCtrl', ($scope) ->

      $scope.aceLoaded = (editor) ->
        editor.setTheme("ace/theme/chaos");
        editor.getSession().setMode("ace/mode/lobster");
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
        editor.getSession().setUseSoftTabs(true);
        editor.setHighlightSelectedWord(true);

Ace needs a statically sized div to initialize, but we want it
to be the full page, so make it so.

        $("#editor").height "#{$(window).height() * 0.85 }px"
        editor.resize()



      $scope.editor_data = "hello"




    vespaControllers.controller 'avispaCtrl', ($scope) ->

      $scope.$on '$locationChangeStart', (event) ->
        console.log "Activated"

