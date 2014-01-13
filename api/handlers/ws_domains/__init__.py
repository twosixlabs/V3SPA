import logging

__DOMAINS__  = {}
import lobster
__DOMAINS__['lobster'] = lobster.instantiate()

def dispatch(msg):

  if not all(map(lambda x: x in msg, ('domain', 'request', 'payload'))):
    logging.critical("Unable to understand formatting of WS message {0}"
                     .format(msg))

  try:
    return __DOMAINS__[msg['domain']].handle(msg)
  except KeyError:
    logging.error("No domain handler known for '{0}'".format(msg['domain']))
    raise KeyError("No domain handler known for '{0}'".format(msg['domain']))

