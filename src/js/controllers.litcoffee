    vespaControllers = angular.module('vespaControllers', ['ui.ace'])

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
        $("#editor").height "#{$(window).height()}px"
        editor.resize()



      console.log "Loaded"
      $scope.editor_data = "hello"


    vespaControllers.controller 'avispaCtrl', ($scope) ->
