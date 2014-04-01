import api
import logging
logger = logging.getLogger(__name__)

from tornado import httpclient

__MIN_LSR_VERSION__ = 2

class LobsterDomain(object):

    """Docstring for LobsterDomain """

    def __init__(self):
        """ Test the connection to the lobster server. """

        backend_uri = "http://{0}/version".format(
            api.config.get('lobster_backend', 'uri'))

        try:
            http_client = httpclient.HTTPClient()
            result = http_client.fetch(
                backend_uri,
                method='GET',
                request_timeout=10.0
            )

            resp = api.db.json.loads(result.body)
            self._lobster_version = resp['version']

            if self._lobster_version < __MIN_LSR_VERSION__:
              logging.critical("Required lobster version {0} but server speaks {1}"
                               .format(__MIN_LSR_VERSION__, self._lobster_version))

            logging.info("Connected to lobster backend server v{0}"
                         .format(self._lobster_version))
        except httpclient.HTTPError as e:
            if e.code == 599:
                raise Exception("backend:lobster - Unavailable")

            else:
                # Our request wasn't valid anyway, we just wanted a response
                pass

    @staticmethod
    def _make_request(method, path, payload, timeout=10.0):
        http_client = httpclient.HTTPClient()
        backend_uri = "http://{0}{1}".format(
            api.config.get('lobster_backend', 'uri'),
            path)

        try:
            output = http_client.fetch(
                backend_uri,
                method=method,
                body=payload,
                request_timeout=timeout
            )
        except httpclient.HTTPError as e:
            if e.code == 599:
                raise Exception("backend:lobster - Unavailable")
            else:
                if api.config.get('main', 'debug'):
                    raise Exception(
                        "Backend error: [{0}] {1}".format(e.code, e.message))
                else:
                    raise Exception("backend:lobster - Unspecified Error")
        else:
          return output

    def validate(self, msg):
        """ Validate a Lobster file received from the IDE
        """

        output = self._make_request('POST', '/parse?{0}'.format(msg['payload']['params']),
            msg['payload']['text'])

        return {
            'label': msg['response_id'],
            'payload': output.body
        }

    def translate_selinux(self, params):
        """ Given a set of parameters of the form, return the
        lobster DSL for the module.

            {
              "refpolicy": "minimal",
              "modules": [
                { "name": "test",
                  "if": " ... source of .if file ...",
                  "te": " ... source of .te file ...",
                  "fc": " ... source of .fc file ..."
                }
              ]
            }
        """
        output = self._make_request('POST', '/import/selinux',
            params if isinstance(params, basestring) else api.db.json.dumps(params))

        return api.db.json.loads(output.body)

    def handle(self, msg):
        if msg['request'] == 'validate':
            return self.validate(msg)
        else:
            raise


def __instantiate__():
    return LobsterDomain()
