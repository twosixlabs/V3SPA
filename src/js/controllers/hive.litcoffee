    vespaControllers = angular.module('vespaControllers')

    vespaControllers.controller 'hiveCtrl', ($scope, VespaLogger, IDEBackend, PositionManager)->
      `
      function leafCount(domain_id, rawData) {
        var domain = rawData.domains[domain_id];

        if (typeof domain === 'undefined') {
          return 0;
        }

        var memo = _.reduce(domain.subdomains, function(memo, v, k) {
          return memo + leafCount(k, rawData);
        }, 0);

        rawData.domains[domain_id].leafCount = memo;
        return memo + 1;
      }

      var config = {
        elemType: "g",
        textFn: function (d) { console.log(d.name); return d.name; },
        leafSize: 20,
        width: 200
      };

      function turtlesAllTheWayDown(d3Selection, startDomain, rawData, depth) {

        /* This part handles this levels display */
        var box = d3Selection.append('g')
        box.append('rect')
            .attr('fill', '#99ccff')
            .attr('width', config.width)
            .attr('height', function(d) {
                if (d.leafCount === 0) {
                  return config.leafSize;
                } 
                return (d.leafCount) * config.leafSize * 1.40
      })
        
        box.append('text')
          .text(config.textFn)
            .attr('font-size', '16')
            .style('text-anchor', 'middle')
            //.style('dominant-baseline', 'middle')
            .attr('x', config.width / 2)
            .attr('y', function(d) {
                return (d.leafCount * config.leafSize / 2) + (config.leafSize / 2) + 5
              })
        
        
        /* The rest of this function handles subdomains */
        var nextLevel = d3Selection.selectAll(config.elemType +".subdomGroup")
        .data(_.values(_.pick(rawData.domains, _.keys(startDomain.subdomains))))
        
        nextLevel
          .enter().append(config.elemType)
            .classed('subdomGroup', true)
            .attr('transform', function(d, i) {
          var param = "translate(";
          param += config.width * 1.25 * depth;
          param += ", ";
          param += (i) * config.leafSize * 1.4;
          param += ")";
          
          return param;
        })

        /* Recursively call this function for subdomains */
        nextLevel.each(function(d, i){
          turtlesAllTheWayDown(d3.select(this), d, rawData, depth + 1);
        });
        
        /*
        var subdom = curr.append('g').classed('subdomGroup', true)
          .attr('transform', function(d, i) {
          var param = "translate(";
          param += 150 * depth;
          param += ", 25)";
          
          return param;
        })
        */


      }
      
      
      
      `

      update_listener = (json_data)->

        if not json_data.result?
          return

        positionMgr = PositionManager("hive.viewport::#{IDEBackend.current_policy._id}")

        leafCount("0", json_data.result)
        `
        var rawData = json_data.result;
        var startDomain = json_data.result.domains["0"];
        var firstLevel = d3.select("svg.hiveview").selectAll('g.subdomGroup')
            .data(_.values(_.pick(rawData.domains, _.keys(startDomain.subdomains))))


        firstLevel.enter().append(config.elemType)
          .classed('subdomGroup', true)
            .attr('transform', function(d, i) {
            var param = "translate(";
            param += 50;
            param += ", 20)";
            
            return param;
          })


          firstLevel.each(function(d, i){
            turtlesAllTheWayDown(d3.select(this), d, rawData, 1);
          });
        `

        svgPanZoom.init
          selector: '#surface svg'
          panEnabled: true
          zoomEnabled: true
          dragEnabled: false
          minZoom: 0.5
          maxZoom: 10
          onZoom: (scale, transform)->
            positionMgr.update transform
          onPanComplete: (coords, transform) ->
            positionMgr.update transform

        $scope.$watch(
          ->
            (positionMgr.data)
        , 
          (newv, oldv)->
            if not newv? or _.keys(newv).length == 0
              return
            g = svgPanZoom.getSVGViewport($("#surface svg")[0])
            svgPanZoom.set_transform(g, newv)
        )

        #if not json_data.domain?
        #  json_data.domain = 
        #    connections: []
        #    subdomains: []
        #
        #plotter '#surface', json_data.domain, (tooltip_html)->
        #
        #  if not tooltip_html?
        #    $("#hivetooltip").hide()
        #    $("#hivetooltip").html("")
        #  else
        #    $('#hivetooltip').html(tooltip_html)
        #    $("#hivetooltip").show()



      IDEBackend.add_hook 'json_changed', update_listener
      $scope.$on '$destroy', ->
        IDEBackend.unhook('json_changed', update_listener)

      start_data = IDEBackend.get_json()
      if start_data
        update_listener(start_data)
