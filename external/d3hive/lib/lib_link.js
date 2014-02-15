// lib_link.js
//
// A shape generator for Hive links, based on a source and a target.
// The source and target are defined in polar coordinates (angle and radius).
// Ratio links can also be drawn by using a startRadius and endRadius.
// This class is modeled after d3.svg.chord.

function make_link() {

  var source      = function(d) { return d.source; },
      target      = function(d) { return d.target; },
      angle       = function(d) { return d.angle;  },
      startRadius = function(d) { return d.radius; },
      endRadius   = startRadius,
      arcOffset   = -Math.PI / 2;


  function link(d, i) {

    var s   = node(source, this, d, i),
        t   = node(target, this, d, i),
        x;

    d.ib_edge = t.a < s.a;

    if (d.ib_edge) x = t, t = s, s = x;

    if (t.a - s.a > Math.PI) s.a += 2 * Math.PI;

    var a1      = s.a + (t.a - s.a) / 3,
        a2      = t.a - (t.a - s.a) / 3,
        cos_a1  = Math.cos(a1),     sin_a1  = Math.sin(a1),
        cos_a2  = Math.cos(a2),     sin_a2  = Math.sin(a2),
        cos_sa  = Math.cos(s.a),    sin_sa  = Math.sin(s.a),
        cos_ta  = Math.cos(t.a),    sin_ta  = Math.sin(t.a);

    if (s.r0 - s.r1 || t.r0 - t.r1) {
      return  'M' + cos_sa * s.r0 + ',' + sin_sa * s.r0 +
              'L' + cos_sa * s.r1 + ',' + sin_sa * s.r1 +
              'C' + cos_a1 * s.r1 + ',' + sin_a1 * s.r1 +
              ' ' + cos_a2 * t.r1 + ',' + sin_a2 * t.r1 +
              ' ' + cos_ta * t.r1 + ',' + sin_ta * t.r1 +
              'L' + cos_ta * t.r0 + ',' + sin_ta * t.r0 +
              'C' + cos_a2 * t.r0 + ',' + sin_a2 * t.r0 +
              ' ' + cos_a1 * s.r0 + ',' + sin_a1 * s.r0 +
              ' ' + cos_sa * s.r0 + ',' + sin_sa * s.r0;
    } else {
      return  'M' + cos_sa * s.r0 + ',' + sin_sa * s.r0 +
              'C' + cos_a1 * s.r1 + ',' + sin_a1 * s.r1 +
              ' ' + cos_a2 * t.r1 + ',' + sin_a2 * t.r1 +
              ' ' + cos_ta * t.r1 + ',' + sin_ta * t.r1;
    }
  }


  function node(method, thiz, d, i) {

    var node  = method.call(thiz, d, i),
        a     = +(typeof angle       === 'function'
                    ? angle.call(thiz, node, i)
                    : angle) + arcOffset,
        r0    = +(typeof startRadius === 'function'
                    ? startRadius.call(thiz, node, i)
                    : startRadius),
        r1t   = +(typeof endRadius   === 'function'
                    ? endRadius.call(thiz, node, i)
                    : endRadius),
        r1    = startRadius === endRadius ? r0 : r1t;

    return { r0: r0, r1: r1, a: a };
  }


  function make_func(object, method) {

    eval(object + '.' + method + "= function(_) {\n" +
         '  if (!arguments.length) return ' + method + ";\n" +
         '    ' + method + "= _;\n" +
         '    return ' + object + ";\n};\n" );
  }

  make_func('link', 'source');
  make_func('link', 'target');
  make_func('link', 'angle');
  make_func('link', 'startRadius');
  make_func('link', 'endRadius');

  link.radius = function(_) {
    if (!arguments.length) return startRadius;
    startRadius = endRadius = _;
    return link;
  };

  return link;
}

module.exports = make_link
