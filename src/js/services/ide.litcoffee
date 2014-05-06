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

          @hooks =
            policy_load: []
            doc_changed: []
            json_changed: []
            validation: []

          @selection_ranges = {}

          @validate_dsl = _.throttle @_validate_dsl, 1000

          @queryparams = null

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
                errors: ["nodata"]
              id: null
              _id: null
              type: null
              valid: false

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
            valid: false

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

Send a request to the server to validate the current
contents of @current_policy

        _validate_dsl: =>
          deferred = @$q.defer()

          req =
            domain: 'lobster'
            request: 'validate'
            payload:
              text: @current_policy.documents.dsl.text
              params: @queryparams

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

              if @current_policy.json.errors.length > 0
                @current_policy.valid = false

              else
                @current_policy.valid = true

              deferred.resolve()

          return deferred.promise

Load a policy from the server

        load_policy: (refpolicy_id, module_name)=>
          deferred = @$q.defer()

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
            @validate_dsl()

            deferred.resolve(@current_policy)

          return deferred.promise

Save a modified policy to the server

        save_policy: =>

          deferred = @$q.defer()

          req =
            domain: 'policy'
            request: 'update'
            payload: @current_policy

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

          annotation = _.find object.domainAnnotations, (elem)->
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
            type: "source_domain"
            apply_to: 'dsl'

          return info

