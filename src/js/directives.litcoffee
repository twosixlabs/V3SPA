    v3spa = angular.module 'vespa'

    v3spa.directive 'autoHeight', ($window) ->
      ret =
        restrict: 'A'
        replace: false
        transclude: false
        scope:
          multiplier: '@autoHeight'
          resize_callback: '&onResize'
        controller: ($scope, $element)->
          angular.element($window).bind 'resize', ->
            $scope.$apply ->
              $element.height "#{$window.innerHeight * $scope.multiplier}px"

            if $scope.resize_callback
              $scope.resize_callback()
        link: (scope, element)->
          element.height "#{$window.innerHeight * scope.multiplier}px"
          scope.resize_callback()

      return ret

    v3spa.directive 'spinnerIcon', ->
      ret =
        restrict: 'A'
        replace: true
        transclude: true
        scope: 
          loading: '= spinnerIcon'
          opts: '= opts'
        template:  """
          <div>
            <div class='spinner-container' ng-show='loading'></div>
            <div ng-hide='loading'></div>
          </div>
          """
        link: (scope, element, attrs) ->
          spinner = new Spinner(scope.opts).spin()
          container = element.find('.spinner-container')[0]
          container.appendChild(spinner.el)

      return ret

    v3spa.directive 'v3spaEditor', ->
      ret = 
        restrict: 'A'
        replace: true
        scope:
          contents: '='
        template: """
          <div>
          <div></div>
          <div id='v3spaEditor'>
          </div>
          </div>
        """
        link: (scope, element, attrs)->
          editor = ace.edit(element.$('#v3spaEditor'))
          editor.setTheme("ace/theme/chaos");
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

Set up editor sessions
          lobsterSession = new EditSession scope.contents.dsl, 'ace/mode/lobster'
          lobsterSession.on 'change', (text)->
            $scope.policy.dsl = text

          scope.$watch contents, (contents)->
            lobsterSession.setValue contents

          applicationSession = new EditSession scope.contents.application
          editor.setSession(lobsterSession)

          scope.sessions =  [
            {name: "DSL", session: lobsterSession},
            {name: "application", applicationSession}
          ]

          editor.resize()


      return ret
