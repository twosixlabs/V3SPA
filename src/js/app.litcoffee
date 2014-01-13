    v3spa = angular.module 'vespa', [
      'ngRoute',
      'vespaControllers'
    ]

    v3spa.config(['$routeProvider',
      ($routeProvider)->
        $routeProvider
          .when '/avispa', 
            templateUrl: 'partials/avispa.html',
            controller: 'avispaCtrl'

          .otherwise 
            redirectTo: '/avispa'
    ])

    v3spa.service 'TokenService', 
      class TokenGenerator
        constructor: ->
          @MAX = 9e15
          @MIN = 1e15
          @safegap = 1000
          @counter = @MIN

        generate: ->
          increment = Math.floor(@safegap*Math.random())
          if @counter > (@MAX - increment)
            @counter = @MIN
          @counter += increment
          return @counter.toString(36)

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
