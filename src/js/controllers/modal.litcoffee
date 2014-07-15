    vespaControllers = angular.module('vespaControllers') 

    vespaControllers.controller 'modal.analysis_controls', (
        $scope, $modalInstance, origin_id_accessor, port_data, IDEBackend) ->

        $scope.port_data = port_data

        $scope.analysis_ctrl =
          limit: 10
          perms: if port_data.name == 'active' then [] else _.pluck(
            _.filter(IDEBackend.current_policy.json.permset, (d)->(
              d.text.lastIndexOf("#{port_data.name}.", 0) == 0
          )), 'text')
          trans_perms: []
          direction: if port_data.name == 'active' then 'forward' else 'backward'

        $scope.cancel = $modalInstance.dismiss

        $scope.load = ->

          query = IDEBackend.perform_path_query(
            origin_id_accessor(port_data),
            $scope.analysis_ctrl)

          query.catch (error)->
            console.log("ERROR", error)

          query.then (paths)->
            $modalInstance.close(paths)

        $scope.permissions_select2 = 
            multiple: true
            data: IDEBackend.current_policy.json.permset
            simple_tags: true
            dropdownAutoWidth: true
            placeholder: 'Filter permissions'
            minimumInputLength: 2
            matcher: (term, text, option)->
                if term.indexOf('.') > 0
                    return text.toUpperCase().indexOf(term.toUpperCase())>=0
                else # if there's no period in the search, just search attributes
                    [objclass, perm] = text.split('.')
                    return perm.toUpperCase().indexOf(term.toUpperCase())>=0
            sortResults: (results, container)->
                return results.sort((a,b)->
                    if a.id < b.id
                        return -1
                    else if a.id > b.id
                        return 1
                    else 
                        return 0
                )


    vespaControllers.controller 'modal.view_module', (
        $scope, $modalInstance, documents, module, $timeout) ->

            $scope.module_name = module
            $scope.documents = documents

            $timeout ->
              $("pre code").html (index, html) ->
                html.replace(/^(.*)$/mg, "<span class=\"line\">$1</span>")

    vespaControllers.controller 'modal.policy_load', (
        $scope, $modalInstance, RefPolicy, $fileUploader) ->

            $scope.input = 
              refpolicy: null
              files: {}

            $scope.invalid = ->
              return not $scope.input.files.te?
            $scope.add_file_input = (file, input_name)->
              $scope.$apply ->
                $scope.input.files[input_name] = file

            $scope.load = ->
              $modalInstance.close($scope.input)

            $scope.cancel = ->
              $modalInstance.dismiss('cancel')

    vespaControllers.controller 'modal.policy_open', (
      $scope, $modalInstance, RefPolicy, IDEBackend) ->

            $scope.selection = 
                refpolicy: RefPolicy.current_as_select2()

Watcher to make sure the reference policy modules get listed
when the reference policy is selected.

            $scope.modules = null
            $scope.$watch( 
              ->
                $scope.selection.refpolicy
            ,
              (newv, oldv)->
                if newv?
                  promise = RefPolicy.list_modules(newv.id)
                  promise.then (data)->
                    $scope.modules = data[0].modules
            )

            $scope.cancel = $modalInstance.dismiss

Loader for the reference policy dropdown

            $scope.policySelectOpts = 
              query: (query)->
                promise = RefPolicy.list()
                promise.then(
                  (policy_list)->
                    dropdown = 
                      results:  for d in policy_list
                        id: d._id.$oid
                        text: d.id
                        data: d
                        disabled: IDEBackend.current_policy.refpolicy_id == d._id.$oid

                    query.callback(dropdown)
                )

Load the clicked on policy into the IDE.

            $scope.load = (name)->
              if not $scope.selection.refpolicy?
                $modalInstance.dismiss()

              $scope.loading = true

              promise = IDEBackend.load_policy $scope.selection.refpolicy.id, name

              promise.then(
                (data)->
                  console.log "Loaded policy successfully"
                  $scope.loading = false
              ,
                (error)->
                  $.growl "Failed to load policy", 
                    type: 'warning'
                  console.log "Policy load failed: #{error}"
                  $scope.loading = false
              )

              $modalInstance.close() 

