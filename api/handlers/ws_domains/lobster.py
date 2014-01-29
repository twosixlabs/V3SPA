import pkg_resources
import api
import logging
logger = logging.getLogger(__name__)

from tornado.process import Subprocess
from tornado.gen import coroutine, Task, Return

from tornado import httpclient


@coroutine
def call_subprocess(cmd):

    proc = Subprocess(cmd,
                      stdout=Subprocess.STREAM,
                      stderr=Subprocess.STREAM)

    result, error = yield [Task(proc.stdout.read),
                           Task(proc.stderr.read)]

    logging.info("Returned: {0}, {1}".format(result, error))

    raise Return((result, error))


class LobsterDomain(object):

    """Docstring for LobsterDomain """

    def __init__(self):
        """ Start the Lobster server """
        backend = api.config.get('lobster_backend', 'resource')

        bin_path = pkg_resources.resource_filename(
            ".".join(backend.split('.')[:-1]),
            backend.split('.')[-1])

        args = [bin_path, "--port", api.config.get('lobster_backend', 'port')]

        call_subprocess(args)

    def backend_exited(self, errcode):
        if errcode != 0:
            raise SystemExit()

    def validate(self, msg):
        """ Validate a Lobster file received from the IDE
        """

        backend_uri = "http://localhost:{0}/parse".format(
            api.config.get('lobster_backend', 'port'))

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
