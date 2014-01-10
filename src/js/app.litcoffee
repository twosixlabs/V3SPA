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

