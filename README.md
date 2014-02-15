d3hive
======

A package to facilitate building [hive plots](http://hiveplot.net) plots using D3.

Designed to be bundled and then required in the browser using
browserify.

To build:

    $ npm install  #dependencies
    $ gulp coffee

To use:

    <script src='d3.js'></script>
    <script src='hive.js'></script>
    <script type='text/javascript'>
        hive = require('hive')
        hive('#my_plot', data)
    </script>
