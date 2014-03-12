    mod = angular.module 'vespa.services'


A service designed to encapulate all of the data interaction
required by the IDE. Responsible for making queries, understanding
errors, and generally being awesome.

    mod.service 'IDEBackend',
      class IDEBackend
        constructor: (@VespaLogger, @$rootScope,
        @SockJSService, @$q, @$timeout)->

          @current_policy = 
            application: ""
            dsl: ""
            json: null
            id: null
            _id: null
            valid: false

          @hooks = 
            policy_load: []
            dsl_changed: []
            app_changed: []
            json_changed: []
            validation: []

          @validate_dsl = _.throttle @_validate_dsl, 1000

        isCurrent: (id)=>
          id? and id == @current_policy._id

Add a hook on certain changes in the backend. The action
will be called as appropriate.

        add_hook: (event, action)=>
          @hooks[event] ?= []
          @hooks[event].push(action)

        unhook: (event, action)=>
          @hooks[event] = _.filter @hooks[event], (hook_fn)->
            action != hook_fn

Create a new policy, but don't save it or anything

        new_policy: (args)=>
          @current_policy = 
            application: ""
            dsl: ""
            json: null
            id: null
            _id: null
            type: null
            valid: false

          for arg, val of args
              @current_policy[arg] = val

          for hook in @hooks.dsl_changed
            hook(@current_policy.dsl)

          for hook in @hooks.app_changed
            hook(@current_policy.application)

          for hook in @hooks.policy_load
            hook(@current_policy)


An easy handle to update the stored representation of
the DSL. Any required callbacks (like updating the
application representation) can be done from here

        update_dsl: (newtext)=>
          @current_policy.dsl = newtext

          # If we are currently running a validation cycle,
          # then set a timeout for 10 seconds, then re-validate if 
          # someone wants us to
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
          annotations.highlights.push @_parseClassSourcePosition (object)
          annotations.highlights.push @_parseDomainSourcePosition (object)


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
            payload: @current_policy.dsl

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

        load_policy: (id)=>
          deferred = @$q.defer()

          req = 
            domain: 'policy'
            request: 'get'
            payload: 
              _id: id

          @SockJSService.send req, (data)=>
            if data.error
              deferred.reject(data.payload)

            @current_policy.application = data.payload.application
            @current_policy.dsl = data.payload.dsl
            @current_policy._id = data.payload._id.$oid
            @current_policy.id = data.payload.id
            @current_policy.valid = false

            for hook in @hooks.dsl_changed
              hook(@current_policy.dsl)

            for hook in @hooks.app_changed
              hook(@current_policy.application)

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


Upload a new policy to the server

        upload_policy: (data)=>


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
            apply_to: 'lobster'

          return info

        _parseDomainSourcePosition: (object)-> 
          annotation = _.find object.domainAnnotations, (elem)->
            elem.name == 'SourcePos'

          info = 
            range:
              start:
                row: annotation.args[1] - 1
                column: annotation.args[2] - 1
              end:
                row: annotation.args[1] - 1
                column: "domain #{object.name}".length
            description: "unknown"
            type: "source_domain"
            apply_to: 'lobster'

          return info

