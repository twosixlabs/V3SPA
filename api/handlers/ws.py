import logging
import api
import traceback

from sockjs.tornado import SockJSRouter, SockJSConnection
import ws_domains
import tornado.gen as gen


class WebSocket(SockJSConnection):

    def on_open(self, channel):
        logging.warn("OPENED CHANNEL: {0}".format(channel.ip))

    @gen.coroutine
    def on_message(self, msg):
        try:
          msg_obj = api.db.json.loads(msg)
          resp = yield gen.Task(ws_domains.dispatch, msg_obj)

        except Exception as e:
          if self.session.server.app.settings['debug']:
            resp = {
                'payload': traceback.format_exc(),
                'error': True
            }

            if 'response_id' in msg_obj:
              resp['label'] = msg_obj['response_id']

            self.send(api.db.json.dumps(resp))
        else:
          if resp is not None:
            self.send(api.db.json.dumps(resp))


class WSRouter(SockJSRouter):
  def __init__(self, *args, **kwargs):
    SockJSRouter.__init__(self, *args, **kwargs)
    try:
      self.app = kwargs['application']
    except KeyError:
      pass

  def set_application(self, app):
    self.app = app
