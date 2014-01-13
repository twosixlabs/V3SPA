import socket
import logging
import json

from sockjs.tornado import SockJSRouter, SockJSConnection
import ws_domains

class WebSocket(SockJSConnection):

    def on_open(self, channel):
        logging.warn("OPENED CHANNEL: {0}".format(channel.ip))

    def on_message(self, msg):
        try:
          msg_obj = json.loads(msg)
          resp = ws_domains.dispatch(msg_obj)
        except Exception as e:
          if self.session.server.app.settings['debug']:
            resp = {
                'error': str(e),
                }

            if 'response_id' in msg_obj:
              resp['label'] = msg_obj['response_id']

            self.send(json.dumps(resp))
        else:
          if resp is not None:
            self.send(json.dumps(resp))

class WSRouter(SockJSRouter):
  def __init__(self, *args, **kwargs):
    SockJSRouter.__init__(self, *args, **kwargs)
    try:
      self.app = kwargs['application']
    except KeyError:
      pass

  def set_application(self, app):
    self.app = app
