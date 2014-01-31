import api
import logging
logger = logging.getLogger(__name__)

from tornado import httpclient


class LobsterDomain(object):

    """Docstring for LobsterDomain """

    def __init__(self):
        """ Test the connection to the lobster server. """

        backend_uri = "http://{0}/info".format(
            api.config.get('lobster_backend', 'uri'))

        try:
            http_client = httpclient.HTTPClient()
            http_client.fetch(
                backend_uri,
                method='POST',
                body="NONE",
                request_timeout=10.0
            )
        except httpclient.HTTPError as e:
            if e.code == 599:
                raise SystemExit(
                    "Could not contact Lobster backend at http://{0}"
                    .format(api.config.get('lobster_backend', 'uri')))

            else:
                # Our request wasn't valid anyway, we just wanted a response
                pass

    def validate(self, msg):
        """ Validate a Lobster file received from the IDE
        """

        backend_uri = "http://{0}/parse".format(
            api.config.get('lobster_backend', 'uri'))

        http_client = httpclient.HTTPClient()

        try:
            output = http_client.fetch(
                backend_uri,
                method='POST',
                body=msg['payload'],
                request_timeout=10.0
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

        return {
            'label': msg['response_id'],
            'payload': output.body
        }

    def handle(self, msg):
        if msg['request'] == 'validate':
            return self.validate(msg)
        else:
            raise


def instantiate():
    return LobsterDomain()
