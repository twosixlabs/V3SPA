    mod = angular.module 'vespa.services'


A service designed to encapulate all of the data interaction
required by the IDE. Responsible for making queries, understanding
errors, and generally being awesome.

    mod.service 'IDEBackend',
      class IDEBackend
        constructor: (@VespaLogger, @$rootScope,
        @SockJSService, @$q, @$timeout) ->

          @current_policy =
            refpolicy_id: null
            documents: {}
            json: null
            id: null
            _id: null
            valid: false

          @graph_expansion = {}
          @graph_id_expansion = []
          @view_control = {}
          @query_params = {}

          @hooks =
            policy_load: []
            doc_changed: []
            json_changed: []
            validation: []

          @selection_ranges = {}

          @validate_dsl = _.debounce @_validate_dsl, 500
          @parse_raw = _.debounce @_parse_raw, 500

        isCurrent: (id)=>
          id? and id == @current_policy._id

        add_selection_range_object: (doc, line, obj)->
          @selection_ranges ?= {}
          @selection_ranges[doc] ?= []
          @selection_ranges[doc][line] ?= []

          @selection_ranges[doc][line].push obj

Call the highlight function on each object registered in
@selection_ranges[doc] on lines within within the specified range.

        highlight_selection: (doc, range)->
          covered = _.groupBy @selection_ranges?[doc], (obj, line)->
            if line - 1>= range.start.row and line - 1  <= range.end.row
              return 'highlight'
            else
              return 'unhighlight'

          _.invoke _.flatten(covered.highlight), 'highlight'
          _.invoke _.flatten(covered.unhighlight), 'unhighlight'


Add a hook on certain changes in the backend. The action
will be called as appropriate.

        add_hook: (event, action)=>
          @hooks[event] ?= []
          @hooks[event].push(action)

        unhook: (event, action)=>
          @hooks[event] = _.filter @hooks[event], (hook_fn)->
            action != hook_fn

Clear the current policy

        clear_policy: =>
            @current_policy =
              documents: {}
              json:
                parameterized: null
                errors: ["nodata"]
                summary: []
              id: null
              _id: null
              type: null
              valid: false

            @graph_expansion = {}
            @graph_id_expansion = []

            for hook in @hooks.policy_load
              hook(@current_policy)

            for hook in @hooks.doc_changed
              for docname, doc of @current_policy.documents
                hook(docname, doc.text)

            _.each @hooks.json_changed, (hook)=>
              hook(@current_policy.json)

            _.each @hooks.on_close, (hook)->
              hook()

Create a new policy, but don't save it or anything

        new_policy: (args)=>
          @current_policy =
            documents: {}
            json: null
            id: null
            _id: null
            type: null
            valid: true

          for arg, val of args
              @current_policy[arg] = val

          if @current_policy.type == 'selinux'
            @current_policy.documents =
              dsl:
                mode: 'lobster'
                text: ''

          for hook in @hooks.policy_load
            hook(@current_policy)

          for hook in @hooks.doc_changed
            for docname, doc of @current_policy.documents
              hook(docname, doc.text)


An easy handle to update the stored representation of
the DSL. Any required callbacks (like updating the
application representation) can be done from here

        update_document: (doc, newtext)->
          @current_policy.documents[doc].text = newtext

          if doc == 'dsl'
            @validate_dsl()

          if doc == 'raw'
            @parse_raw()

Return the JSON representation if valid, and null if it is
invalid

        get_json: =>
          if @current_policy.valid
            return @current_policy.json

Send notifications to those listing to validation hooks
about highlighting that should be performed.

        highlight: (object)=>
          annotations =
            highlights: []

          if object?
            clsSrcPos = @_parseClassSourcePosition object
            annotations.highlights.push clsSrcPos if clsSrcPos?
            domSrcPos = @_parseDomainSourcePosition object
            annotations.highlights.push domSrcPos if domSrcPos?

          _.each @hooks.validation, (hook)->
            hook annotations

        unhighlight: =>
          _.each @hooks.validation, (hook)->
            hook([])

The locally stored set of domains that we expand can get both
very large, and out of sync. Re-build it from the local data
store

        rebuild_expansion: =>
          data = @current_policy.json['result']['domains']

          @graph_expansion = {}
          @graph_id_expansion = 

          ancestor_lists = []
          for id, domain of data
            do (id, domain)->
              ancestor_lists.push(domain.path.split('.'))

          _.each ancestor_lists, (ancestor_list)=>
            curr = @graph_expansion
            for elem in ancestor_list
                if elem not of curr
                    curr[elem] = {}

                curr = curr[elem]

Extend the set of paths that we show.

        expand_graph_by_id: (id_list)=>
          to_add = _.difference(id_list, @graph_id_expansion)
          if to_add.length > 0
            @graph_id_expansion = @graph_id_expansion.concat id_list
            @_validate_dsl()

        contract_graph_by_id: (id_list)=>
          @graph_id_expansion = _.without.apply(
            _, [@graph_id_expansion].concat(id_list))
          @_validate_dsl()

        expand_graph_by_name: (ancestor_lists)=>

          _.each ancestor_lists, (ancestor_list)=>
            curr = @graph_expansion
            for elem in ancestor_list
                if elem not of curr
                    curr[elem] = {}

                curr = curr[elem]

          @_validate_dsl()

Compose the graph expansion dictionary as a
set of paths.

        write_filter_param: (paths)->
          params = ["path="]

          recurse = (current, paths, params)->
            unless current == ""
              current += "."
            _.each paths, (obj, key)->
              if _.isEmpty obj
                params.push "path=#{current}#{key}"
              else
                recurse("#{current}#{key}", obj, params)

          recurse("", paths, params)

          return params

Set the visibility of a given key. If we have a policy loaded, then
trigger revalidation.

        set_query_param: (param, val)->
          if @query_params[param] != val
            @query_params[param] = val

        set_view_control: (key, visible)->
          if @view_control[key] != visible
            @view_control[key] = visible

            unless @current_policy.id == null
              @validate_dsl()

Send a request to the server to parse the raw policy and return the JSON parsed
version of the policy.

        _parse_raw: =>
          deferred = @$q.defer()

          path_params = @write_filter_param(@graph_expansion)
          path_params = _.union(path_params, 
                                _.map(@graph_id_expansion, (v)->
                                    "id=#{v}"
                                )
          )

          req =
            domain: 'raw'
            request: 'parse'
            payload:
              policy: @current_policy._id
              text: @current_policy.documents.raw.text
              params: path_params.join("&")
              hide_unused_ports: if @view_control.unused_ports then false else true


          @SockJSService.send req, (result)=>
            if result.error  # Service error

              $.growl(
                title: "Error"
                message: result.payload
              ,
                type: 'danger'
              )

              deferred.reject result.payload

            else  # valid response. Must parse
              @current_policy.json = JSON.parse result.payload

              # For now, disable calling the validation hooks because they are
              # related to the DSL and not raw policies.
              # for hook in @hooks.validation
              #   annotations =
              #     errors: @current_policy.json.errors
              #   hook(annotations)

              _.each @hooks.json_changed, (hook)=>
                hook(@current_policy.json)

              deferred.resolve()

          return deferred.promise

Send a request to the server to validate the current
contents of @current_policy and get the parsed JSON

        _validate_dsl: =>
          deferred = @$q.defer()

          path_params = @write_filter_param(@graph_expansion)
          path_params = _.union(path_params, 
                                _.map(@graph_id_expansion, (v)->
                                    "id=#{v}"
                                )
          )

          req =
            domain: 'lobster'
            request: 'validate'
            payload:
              policy: @current_policy._id
              text: @current_policy.documents.dsl.text
              params: path_params.join("&")
              hide_unused_ports: if @view_control.unused_ports then false else true


          @SockJSService.send req, (result)=>
            if result.error  # Service error

              $.growl(
                title: "Error"
                message: result.payload
              ,
                type: 'danger'
              )

              deferred.reject result.payload

            else  # valid response. Must parse
              @current_policy.json = JSON.parse result.payload

              for hook in @hooks.validation
                annotations =
                  errors: @current_policy.json.errors
                hook(annotations)

              _.each @hooks.json_changed, (hook)=>
                hook(@current_policy.json)

              deferred.resolve()

          return deferred.promise

        load_local_policy: (refpolicy)=>

            @graph_expansion = {}

            @current_policy = refpolicy
            @current_policy.valid = true

            # Adding this because raw views do not have editor, and therefore no document or text
            # So need to manually trigger getting the raw json
            @parse_raw()

            for hook in @hooks.policy_load
              hook(@current_policy)

            for hook in @hooks.doc_changed
              for docname, doc of @current_policy.documents
                hook(docname, doc.text)

            $.growl
              title: "Loaded"
              message: "#{@current_policy.id}"

            # Validate the dsl that was returned immediately
            #@validate_dsl()

Load a policy module from the server (deprecated)

        load_policy_module: (refpolicy_id, module_name)=>
          console.error "This function is deprcated..."
          deferred = @$q.defer()

          @graph_expansion = {}
          @graph_id_expansion = []

          req =
            domain: 'policy'
            request: 'get'
            payload:
              refpolicy_id: refpolicy_id
              id: module_name

          @SockJSService.send req, (data)=>
            if data.error
              deferred.reject(data.payload)
              return

            mod = data.payload
            @current_policy = mod
            @current_policy._id = mod._id.$oid

            @current_policy.documents = mod.documents
            @current_policy.id = mod.id
            @current_policy.valid = false

            for hook in @hooks.policy_load
              hook(@current_policy)

            for hook in @hooks.doc_changed
              for docname, doc of @current_policy.documents
                hook(docname, doc.text)

            $.growl
              title: "Loaded"
              message: "#{@current_policy.id}"

            # Validate the dsl that was returned immediately
            #@validate_dsl()

            deferred.resolve(@current_policy)

          return deferred.promise

Save a modified policy to the server

        save_policy: =>

          deferred = @$q.defer()

          req =
            domain: 'refpolicy'
            request: 'update'
            payload: 
              _id: @current_policy._id
              dsl: @current_policy.documents.dsl.text

          delete req.payload.json

          @SockJSService.send req, (resp)=>
            if resp.error  # Service error
              @VespaLogger.log 'policy', 'error', resp.payload
              deferred.reject resp.payload

            else  # valid response. Must parse
              @current_policy._id = resp.payload._id.$oid
              @VespaLogger.log 'policy', 'info',
                "Saved #{@current_policy.id} successfully"
              deferred.resolve @current_policy._id

          return deferred.promise

Set JSON

        list_policies: =>
          deferred = @$q.defer()

          req =
            domain: 'policy'
            request: 'find'
            payload:
              selection:
                id: true

          @SockJSService.send req, (data)->
            if data.error?
              deferred.reject(data.payload)
            else
              deferred.resolve(data.payload)


          return deferred.promise

Given the JSON representation, parse out the type
of information described by these functions. These
are written here to make it easier to change if the
format of the JSON changes (as it likely will).

        _parseClassSourcePosition: (object)->
          annotation = _.find object.classAnnotations, (elem)->
            elem.name == 'SourcePos'

          return unless annotation?

          info =
            range:
              start:
                row: annotation.args[1] - 1
                column: annotation.args[2] - 1
              end:
                row: annotation.args[1] - 1
                column: "class #{object.class}".length
            description: "unknown"
            type: "source_class"
            apply_to: 'dsl'

          return info

        _parseDomainSourcePosition: (object)->

          return unless object.srcloc?
          info =
            range: object.srcloc
            description: "unknown"
            type: "source_domain"
            apply_to: 'dsl'

          return info

Perform a path query originating from the domain with ID
`domain_id`. Return a promise which will be resolved
with the results.

        perform_path_query: (domain_id, params)->
          deferred = @$q.defer()

          path_params = _.map(params, (v, k)->
            if _.isArray v
                if _.size(v) == 0
                    return null
                else
                    return "#{k}=#{v.join(",")}"

            else
                return "#{k}=#{v}"
          )
          path_params = _.reject(path_params, (v)-> v == null)

          req =
            domain: 'lobster'
            request: 'query_reachability'
            payload:
              policy: @current_policy._id
              text: @current_policy.documents.dsl.text
              params: path_params.concat("id=#{domain_id}").join("&")


          @SockJSService.send req, (data)=>
            if data.error?
              deferred.reject(data.payload)
            else
              @current_policy.json = data.payload.data

              ids = []
              _.each @current_policy.json.params.split('&'), (param)->
                [name, val] = param.split('=')
                if name == 'id'
                  ids.push val

              @expand_graph_by_id ids

              _.each @hooks.json_changed, (hook)=>
                hook(@current_policy.json)

              deferred.resolve(data.payload.paths)

          return deferred.promise
