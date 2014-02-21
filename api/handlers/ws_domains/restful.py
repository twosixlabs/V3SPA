import api.storage.interface
import logging
logger = logging.getLogger(__name__)

class ResourceDomain(api.storage.interface.Entry):

  @classmethod
  def handle(cls, msg):
    if 'request' not in msg:
      raise Exception("No method specified")

    method = msg['request'].lower()
    if 'payload' in msg and msg['payload'] is not None:
      params = msg['payload']
    else:
      params = dict()

    response = {}
    if 'response_id' in msg:
        response['label'] = msg['response_id']

    if method == 'find':
      try:
          response['payload'] = cls.Find(
              params.get('criteria', {}),
              params.get('selection', {})
          )
      except KeyError:
        raise Exception("Invalid payload for 'find': {0}".format(
                        msg['payload']))
    elif method == 'get':
      response['payload'] = cls.Read(params)
    elif method == 'create':
      newobject = cls(params)
      response['payload'] =  newobject.Insert()
    elif method == 'update':
      if '_id' in params and params['_id'] is not None:
        newobject = cls.Read(params['_id'])
        response['payload'] = newobject.Update( params)
      else:
        newobject = cls(params)
        response['payload'] =  newobject.Insert()
    elif method == 'delete':
      newobject = cls.Read(params['_id'])
      response['payload'] = newobject.Delete()
    else:
      raise Exception("Unrecognized method: {0}"
                      .format(method))

    return response
