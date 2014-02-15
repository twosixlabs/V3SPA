gulp = require('gulp')
gutil = require('gulp-util')
browserify = require('gulp-browserify')
rename = require('gulp-rename')
plumber = require('gulp-plumber')
uglify = require('gulp-uglify')

gulp.task('coffee', function() {
  gulp.src(['lib/main.litcoffee'], {read: false})
    //.pipe(plumber())
    .pipe(browserify({
      transform: ['coffeeify', 'jadeify'],
      extensions: ['.litcoffee', '.jade'],
      ignore: ['./lib-cov/jade'],
      require: [['./main', {expose:'hive'}]]
    }).on('error', gutil.log)
    )
    //pipe(uglify())
    .pipe(rename( function(path){
      path.dirname = "."
      path.basename = "hive"
      path.extname = ".js"
    }))
    .pipe(gulp.dest('dist'))
    .on('error', gutil.log)
})

gulp.task('default', ['coffee'])

gulp.task('reloader', function(){
  gulp.watch(['lib/*'], ['coffee'])
})
