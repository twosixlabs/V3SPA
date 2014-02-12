var gulp = require('gulp')
var gutil = require('gulp-util')
var coffee = require('gulp-coffee')
var include = require('gulp-include')
var rename = require('gulp-rename')
var uglify = require('gulp-uglify')
var debug = require('gulp-debug')
var less = require("gulp-less")

var paths = {
  html: ['src/index.html', 'src/partials/*.html'],
  less: ['src/less/*.less'],
}



/* Build the application files by including
 * all literate coffeescript files, compiling
 * them and then including all javascript */
gulp.task('application', function(){
  gulp.src('src/js/app.litcoffee')
  .pipe(include({
      extensions:  "litcoffee"
  }))
  .pipe(coffee()).on('error', gutil.log)
  .pipe(include({
    extensions: "js"
  }))
  .pipe(rename(function(path) {
    path.basename = "vespa"
  }))
  .pipe(gulp.dest('static/js'))
})

/* Build all assets using include, output
 * them both minified and not minified */
gulp.task("script_assets", function() {
  gulp.src('external/assets.js')
  .pipe(include({extensions: 'js'}))
  .pipe(gulp.dest('static/js'))
  .pipe(uglify({
    outSourceMap: true,
  }))
  .pipe(rename(function(path){
    path.extname = '.min.js'
  }))
  .pipe(gulp.dest('static/js'))
})

/* Copy HTML files to the static directory */
gulp.task('html', function(){
  gulp.src(paths.html)
  .pipe(gulp.dest('static'))
})

/* Run the LESS preprocessor */
gulp.task('less', function() {
  gulp.src('src/less/vespa.less')
  .pipe(less())
  .pipe(gulp.dest('static/less'))
})

gulp.task('reloader', function() {
  gulp.watch(paths.html, [ 'html' ])
  gulp.watch('external/assets.js', [ 'script_assets' ])
  gulp.watch(['src/**/*coffee'], [ 'application' ])
})

gulp.task('default', ['scripts', 'script_assets', 'html'])
