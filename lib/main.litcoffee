
    HivePlot = require './plot'
    lobster = require './lobster_data'
    flare = require './flare_data'
    mouse = require './mouse'


Render a d3 hive plot inside 'selector', using 'data'.  When tooltips should
be displayed, 'tooltip_display' will be called with the information to put
inside of them

    module.exports = d3_plotter = (selector, data, tooltip_display)->

        plot = new HivePlot selector, lobster.layout('conv')

        lobster.transform(plot, data)
        mouse.setup_mouse(plot, tooltip_display)
        plot.display()

