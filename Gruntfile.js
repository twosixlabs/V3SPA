module.exports = function(grunt) {
  grunt.registerTask('watch', ['watch'])

  grunt.initConfig({
    copy: {
      html: {
        files: [
          {
            expand: true, cwd: 'src', src: ['*.html', 'partials/*.html'],
            dest: 'static/', filter: 'isFile'
          },
          {
            expand: true,
            dest:'static/js/ace/', 
            src: '**',
            cwd: 'external/ace/build/src/',
            filter: 'isFile'
          },
          {
            expand: true,
            dest: 'static/fonts/',
            src: '*',
            cwd: 'external/bootstrap/dist/fonts/',
            filter: 'isFile'
          },
          {
            expand: true,
            dest: 'static/img/',
            src: '*',
            cwd: 'src/img/',
            filter: 'isFile'
          }
        ]
      }
    },
    less: {
      style: {
        files: {
          "static/css/vespa.css": "src/less/vespa.less",
          "static/css/avispa.css": "external/avispa/src/avispa.less",
        }
      }
    },
    uglify: {
      dist: {
        files: [
          {'static/js/lobster-json.js': 'external/node-json-lobster/dist/lobster-json.js'},
          {'static/js/sockjs.0.3.min.js': 'external/sockjs.0.3.min.js'},
          {'static/js/spin.min.js': 'external/spin.min.js'},
          { 
            expand: true, cwd: 'external/angular', 
            dest: 'static/js/', src: 'angular*.js'
          },
          { 
            expand: true, cwd: 'external/backbone', 
            dest: 'static/js/', src: '*.js'
          },
          { 'static/js/bootstrap.js': 'external/bootstrap/dist/js/bootstrap.js'}
        ]
      }
    },
    concat: {
      options: {
        separator: ';',
      },
      dist: {
        src: ['external/jquery-2.0.3.min.js', 'external/jquery-ui-1.10.3.custom.min.js'],
        dest: 'static/js/jquery-combined.js'
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
            'src/js/*.litcoffee',
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
        files: ['src/js/*.litcoffee',
                'src/lobster/*.litcoffee',
                'external/avispa/src/*.litcoffee'],
        tasks: ['coffee'],
      },
      css: {
        files: ['src/less/*.less'],
        tasks: ['less:style'],
        options: {
          livereload: true,
        }
      },
      copy: {
        files: ['src/index.html', 'src/partials/*.html'],
        tasks: ['copy'],
      }
    }

  });

  grunt.loadNpmTasks('grunt-contrib-less');
  grunt.loadNpmTasks('grunt-contrib-watch');
  grunt.loadNpmTasks('grunt-contrib-uglify')
  grunt.loadNpmTasks('grunt-contrib-coffee');
  grunt.loadNpmTasks('grunt-contrib-copy');
  grunt.loadNpmTasks('grunt-contrib-concat');

  grunt.registerTask('default', ['coffee', 'uglify', 'concat', 'less', 'copy'])

}
