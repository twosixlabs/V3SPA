module.exports = function(grunt) {
  grunt.registerTask('watch', ['watch'])

  grunt.initConfig({
    less: {
      style: {
        files: {
          "public/css/vespa.css": "src/vespa.less",
          "public/css/avispa.css": "external/avispa/src/avispa.less",
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
            'src/vespa.litcoffee',
            'src/models.litcoffee',
            'src/router.litcoffee',
            'src/parser.litcoffee',
            'src/lobster/*.litcoffee',
            'src/editor.litcoffee',
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
  grunt.loadNpmTasks('grunt-contrib-coffee');
}
