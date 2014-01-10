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
          { 
            expand: true, cwd: 'external/angular', 
            dest: 'static/js/', src: 'angular*.js'
          },
          { 'static/js/jquery-2.0.3.js': 'external/jquery-2.0.3.min.js'},
          { 'static/js/bootstrap.js': 'external/bootstrap/dist/js/bootstrap.js'}
        ]
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
        files: ['src/js/*.litcoffee', 'src/lobster/*.litcoffee'],
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

  grunt.registerTask('default', ['coffee', 'uglify', 'less', 'copy'])

}
