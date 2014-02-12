var gulp = require('gulp')
var gutil = require('gulp-util')
var coffee = require('gulp-coffee')
var include = require('gulp-include')
var rename = require('gulp-rename')
var debug = require('gulp-debug')

var paths = {
  html: ['src/index.html', 'src/partials/*.html']
}

gulp.task('scripts', function(){
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

gulp.task('html', function(){
  gulp.src(paths.html)
  .pipe(gulp.dest('static'))
})

gulp.task('reloader', function() {
  gulp.watch(paths.html, [ 'html' ])
  gulp.watch(['src/**/*coffee'], [ 'scripts' ])
})

gulp.task('default', ['scripts'])
