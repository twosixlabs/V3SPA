import logging

from tornado import concurrent
from api.util import LazyModule
import pkgutil


__DOMAINS__ = {}
for loader, name, ispkg in pkgutil.iter_modules(__path__):
  __DOMAINS__[name] = LazyModule('api.handlers.ws_domains.' + name,
                                 loader, '__instantiate__')


def call(domain, method, *args, **kwargs):
  if domain not in __DOMAINS__:
    raise KeyError("No domain handler known for '{0}'".format(domain))

  method = getattr(__DOMAINS__[domain], method)

  return method(*args, **kwargs)


@concurrent.return_future
def dispatch(msg, callback=None):

  if not all(map(lambda x: x in msg, ('domain', 'request', 'payload'))):
    logging.critical("Unable to understand formatting of WS message {0}"
                     .format(msg))
    raise Exception("Unable to understand formatting of WS message {0}"
                    .format(msg))

  if msg['domain'] not in __DOMAINS__:
    logging.error("No domain handler known for '{0}'".format(msg['domain']))
    raise KeyError("No domain handler known for '{0}'".format(msg['domain']))

  result = __DOMAINS__[msg['domain']].handle(msg)

  callback(result)
