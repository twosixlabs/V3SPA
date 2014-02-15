    module.exports = {}

    snap = (x)-> return -> x

    module.exports.get_info = (data_set, format) ->

      degree = Math.PI / 180
      x_max = 800
      x_off = x_max * 0.5
      y_max = 800
      y_off = y_max * 0.5

      if format == 'conv'
        a_off = 20
        a_so = 0
        a_st = 120 - a_off
        a_to = -120
        a_ts = 120 + a_off
        i_rad = 25
        o_rad = 400

      else
        a_so    =  -45
        a_st    = 45
        a_to    = -135
        a_ts    = 135
        i_rad   =   25
        o_rad   = 350

      info = 
        global:
          x_max: x_max
          y_max: y_max
          x_off: x_off
          y_off: y_off
          inner_radius: i_rad
          outer_radius: o_rad

        shapes:
          node:
            shape: 'circle'
            attributes:
              r: 4

        axes:
          source:
            angle: degree * a_so
          'source-target':
            angle: degree * a_st
          "target-source":
            angle: degree * a_ts
          target:
            angle: degree * a_to

      return info

