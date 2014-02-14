    #= include ../../external/avispa/src/avispa.litcoffee

    #= require directives.litcoffee
    #= require services/main.litcoffee
    #= require services/ide.litcoffee
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

    `
    $.growl.default_options = {
        ele: "body",
        type: "info",
        allow_dismiss: true,
        position: {
                from: "top",
                align: "center"
            },
        offset: 20,
        spacing: 10,
        z_index: 1031,
        fade_in: 400,
        delay: 5000,
        pause_on_mouseover: false,
        onGrowlShow: null,
        onGrowlShown: null,
        onGrowlClose: null,
        onGrowlClosed: null,
        template: {
                icon_type: 'class',
                container: '<div class="col-xs-10 col-sm-10 col-md-3 alert">',
                dismiss: '<button type="button" class="close" data-dismiss="alert" aria-hidden="true">&times;</button>',
                title: '<strong>',
                title_divider: '',
                message: ''
            }
    };
    `
