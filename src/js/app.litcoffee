    #= require filters.litcoffee
    #= require directives.litcoffee
    #= require services/main.litcoffee
    #= require services/ide.litcoffee
    #= require services/refpolicy.litcoffee
    #= require services/wsutils.litcoffee
    #= require services/position.litcoffee
    #= require controllers.litcoffee
    #= require_tree controllers

    v3spa = angular.module 'vespa', [
      'ngTagsInput',
      'ngRoute',
      'vespaControllers',
      'vespa.directives'
    ]

    v3spa.config(['$routeProvider',
      ($routeProvider)->
        $routeProvider
          .when '/module_browser',
            templateUrl: 'partials/module_browser.html',
            controller: 'module_browserCtrl'

          .when '/diff',
            templateUrl: 'partials/diff.html',
            controller: 'diffCtrl'

          .when '/explore',
            templateUrl: 'partials/explore.html',
            controller: 'exploreCtrl'

          .when '/explore_lobster',
            templateUrl: 'partials/explore_lobster.html',
            controller: 'exploreLobsterCtrl'

          .otherwise 
            redirectTo: '/module_browser'
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

Define a sigmajs node renderer that draws nodes with a border

    sigma.canvas.nodes.border = (node, context, settings) ->
      prefix = settings('prefix') or ''

      context.fillStyle = node.color or settings('defaultNodeColor')
      context.beginPath()
      context.arc(
        node[prefix + 'x'],
        node[prefix + 'y'],
        node[prefix + 'size'],
        0,
        Math.PI * 2,
        true
      )

      context.closePath()
      context.fill()

      context.lineWidth = node[prefix + 'size'] / 4
      context.strokeStyle = node.borderColor or '#ffffff'
      context.stroke()

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


