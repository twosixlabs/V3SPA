    #= include ../../external/avispa/src/avispa.litcoffee

    #= require directives.litcoffee
    #= require services.litcoffee
    #= require controllers.litcoffee
    #= require_tree controllers

    v3spa = angular.module 'vespa', [
      'ngRoute',
      'vespaControllers',
      'vespa.directives'
    ]

    v3spa.config(['$routeProvider',
      ($routeProvider)->
        $routeProvider
          .when '/avispa', 
            templateUrl: 'partials/avispa.html',
            controller: 'avispaCtrl'

          .when '/hive',
            templateUrl: 'partials/hive.html',
            controller: 'hiveCtrl'

          .otherwise 
            redirectTo: '/avispa'
    ])

    v3spa.filter 'filepath', ->
      return (input)->
        if not input?
          return ""
        return input.replace(/\\/g, '/').replace(/.*\//, '')

