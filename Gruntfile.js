module.exports = function(grunt) {
  grunt.registerTask('watch', ['watch'])

  grunt.registerTask('subbuild', function(dir) {
    var done = this.async();

    grunt.log.writeln('processing ' + dir);

    grunt.util.spawn({
      grunt: true,
      args:[ 'package' ],
      opts: {
        cwd: dir
      }
    },

    function(err, result, code) {
      if (err == null) {
        grunt.log.writeln('processed ' + dir);
        done();
      }
      else {
        grunt.log.writeln('processing ' + dir + ' failed: ' + code);
        done(false);
      }
    })
  });

  grunt.initConfig({
    less: {
      style: {
        files: {
          "static/css/vespa.css": "src/vespa.less",
          "static/css/avispa.css": "external/avispa/src/avispa.less",
        }
      }
    },
    uglify: {
      dist: {
        files: {
          'static/js/lobster-json.js': 'external/node-json-lobster/dist/lobster-json.js'
        }
      }
    },
    coffee: {
      compileJoined: {
        options:{
        join: true,
        bare: true,
        literate: true
        },
        files: {
          'static/js/vespa.js': [
            'src/models.litcoffee',
            'src/router.litcoffee',
            'src/parser.litcoffee',
            'src/lobster/*.litcoffee',
            'src/editor.litcoffee',
            'src/vespa.litcoffee',
          ],
          'static/js/avispa.js': [
            'external/avispa/src/avispa.litcoffee',
            'external/avispa/src/templates.litcoffee',
            'external/avispa/src/util.litcoffee',
            'external/avispa/src/objects/base.litcoffee',
            'external/avispa/src/objects/group.litcoffee',
            'external/avispa/src/objects/node.litcoffee',
            'external/avispa/src/objects/link.litcoffee',
          ]
        }
      }
    },

    watch: {
      coffee: {
        files: ['src/*.litcoffee', 'src/lobster/*.litcoffee'],
        tasks: ['coffee'],
      },
      css: {
        files: ['less/*.less'],
        tasks: ['less:style'],
        options: {
          livereload: true,
        }
      }
    }

  });

  grunt.loadNpmTasks('grunt-contrib-less');
  grunt.loadNpmTasks('grunt-contrib-watch');
  grunt.loadNpmTasks('grunt-contrib-uglify')
  grunt.loadNpmTasks('grunt-contrib-coffee');

  grunt.registerTask('rebuild', ['subbuild:external/node-json-lobster', 'uglify'])

}
