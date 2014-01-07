module.exports = function(grunt) {
  grunt.registerTask('watch', ['watch'])

  grunt.initConfig({
    less: {
      style: {
        files: {
          "public/css/vespa.css": "src/vespa.less",
        }
      }
    },
    coffee: {
      compileJoined: {
        options:{
        join: true,
        literate: true
        },
        files: {
          'static/js/vespa.js': [
            'src/lobster/*.litcoffee',
            'src/*.litcoffee',
          ],
          'static/js/avispa.js': [
            'external/avispa/src/objects/*.litcoffee',
            'external/avispa/src/*.litcoffee',
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
