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

        method_impl = getattr(cls, "do_{0}".format(method), None)
        if method_impl is None:
            raise Exception("Unrecognized method: {0}"
                            .format(method))
        else:
            response = method_impl(params, response)

        return response

    @classmethod
    def do_find(cls, params, response):
        try:
            response['payload'] = cls.Find(
                params.get('criteria', {}),
                params.get('selection', {})
            )
            return response
        except KeyError:
            raise Exception("Invalid params for 'find': {0}".format(
                            params))

    @classmethod
    def do_get(cls, params, response):
        import pdb; pdb.set_trace()
        response['payload'] = cls.Read(params)
        return response

    @classmethod
    def do_create(cls, params, response):
        newobject = cls(params)
        response['payload'] = newobject.Insert()
        return response

    @classmethod
    def do_update(cls, params, response):
        if '_id' in params and params['_id'] is not None:
            newobject = cls.Read(params['_id'])
            response['payload'] = newobject.Update(params)
        else:
            newobject = cls(params)
            response['payload'] = newobject.Insert()
        return response

    @classmethod
    def do_delete(cls, params, response):
        newobject = cls.Read(params['_id'])
        response['payload'] = newobject.Delete()
        return response
