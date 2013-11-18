

    Parser =
        Load: (lsr) ->
            #@parent = [vespa.avispa.$objects]
            @parent = [null]
            @Domain(lsr)
            return

        Domain: (domain) ->
            domains = x: 0
            bounds = x: 40, y: 40

            for id,subdomain of domain.subdomains
                subdomain.coords =
                    x: domains.x
                    y: 100
                    w: 200
                    h: 200

                vespa.dispatch.trigger('CreateDomain', subdomain.name, @parent[0], subdomain)

                @parent.unshift(objects[subdomain.name])
                @Domain(subdomain)
                @parent.shift()

                domains.x += 210

            for id,port of domain.ports
                port.coords =
                    x: bounds.x
                    y: bounds.y
                    radius: 30
                    fill: '#eeeeec'
                vespa.dispatch.trigger('CreatePort', id, @parent[0], port)

                bounds.x += 70

            for idx,connection of domain.connections
                vespa.dispatch.trigger('CreateLink',
                    connection.connection,
                    objects[connection.left.port],
                    objects[connection.right.port]
                    )

            return

