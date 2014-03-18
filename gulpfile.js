var gulp = require('gulp')
var gutil = require('gulp-util')
var coffee = require('gulp-coffee')
var include = require('gulp-include')
var rename = require('gulp-rename')
var uglify = require('gulp-uglify')
var debug = require('gulp-debug')
var less = require("gulp-less")
var chug = require('gulp-chug')

var paths = {
  html: ['src/**/*.html'],
  less: ['src/less/*.less'],
  ace: ['external/ace/build/src-min-noconflict/*'],
  select2: [
    'external/select2-3.4.5/*.js',
    'external/select2-3.4.5/*.css',
    'external/select2-3.4.5/*.gif',
    'external/select2-3.4.5/*.png',
  ],
  fonts: [
    'external/bootstrap/dist/fonts/*'
  ],
  images: [
    'src/img/*'
  ]
}

gulp.task('select2', function() {
  gulp.src(paths.select2)
  .pipe(rename(function(path) {
  }))
  .pipe(gulp.dest("static/select2"))
})

gulp.task('fonts', function() {
  gulp.src(paths.fonts)
  .pipe(rename(function(path) {
  }))
  .pipe(gulp.dest("static/fonts"))
})

gulp.task('ace', function() {
  gulp.src(paths.ace)
  .pipe(gulp.dest('static/ace'))
})

gulp.task('images', function() {
  gulp.src(paths.images)
  .pipe(gulp.dest('static/img'))

})

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

/* Copy external assets to the static directory */
gulp.task('assets', function(){
  gulp.src(paths.assets)
  .pipe(gulp.dest('static'))
})

/* Run the LESS preprocessor */
gulp.task('less', function() {
  gulp.src('src/less/vespa.less')
  .pipe(less()).on('error', gutil.log)
  .pipe(gulp.dest('static/css'))
})

gulp.task('reloader', function() {
  gulp.watch(paths.html, [ 'html' ])
  gulp.watch(['external/**/*.js'], ['script_assets'])
  gulp.watch(['src/**/*coffee'], [ 'application' ])
  gulp.watch(paths.less, ['less'])
})

gulp.task('default', [
  'application',
            'less',
            'script_assets',
            'html',
            'select2',
            'ace',
            'images',
            'fonts'
])
