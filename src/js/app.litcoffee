    #= include ../../external/avispa/src/avispa.litcoffee

    #= require filters.litcoffee
    #= require directives.litcoffee
    #= require services/main.litcoffee
    #= require services/ide.litcoffee
    #= require services/refpolicy.litcoffee
    #= require services/position.litcoffee
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

          .when '/tl_explore',
            templateUrl: 'partials/tl_explore.html',
            controller: 'tlCtrl'

          .when '/module_browser',
            templateUrl: 'partials/module_browser.html',
            controller: 'module_browserCtrl'

          .when '/diff',
            templateUrl: 'partials/diff.html',
            controller: 'diffCtrl'

          .otherwise 
            redirectTo: '/blah'
    ])

Preload all of the templates that we're going to use.

    v3spa.run ($templateCache, $http)->
      $templateCache.put('analysisModal.html',
                         $http.get('partials/modal_analysis.html'))
      $templateCache.put('policyLoadModal.html',
                         $http.get('partials/modal_load.html'))
      $templateCache.put('policyNewModal.html',
                         $http.get('partials/modal_new.html'))
      $templateCache.put('policyOpenModal.html',
                         $http.get('partials/modal_open.html'))
      $templateCache.put('refpolicyModal.html',
                         $http.get('partials/modal_refpolicy.html'))
      $templateCache.put('moduleViewModal.html',
                         $http.get('partials/modal_viewmodule.html'))


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


