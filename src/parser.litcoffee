

    Parser =
        Load: (lsr) ->
            @parent = [vespa.avispa.$objects]
            @Domain(lsr)
            return

        Domain: (domain) ->
            for id,subdomain of domain.subdomains
                #console.log '>>>', id, subdomain

                subdomain.coords =
                    x: 70
                    y: 60
                    w: 200
                    h: 200

                vespa.dispatch.trigger('CreateDomain', id, @parent[0], subdomain)

                @parent.unshift(objects[id].$el)
                @Domain(subdomain)
                @parent.shift()

            for id,port of domain.ports
                #console.log '+++', id, port

                port.coords =
                    x: 40
                    y: 40
                    radius: 30
                    fill: '#eeeeec'

                vespa.dispatch.trigger('CreateNode',  id, @parent[0], port)

            return

