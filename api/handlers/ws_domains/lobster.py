import tempfile
import pkg_resources
import api
import logging
logger = logging.getLogger(__name__)

from tornado.process import Subprocess
from tornado.gen import coroutine, Task, Return


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

    with tempfile.NamedTemporaryFile() as temp:
      temp.write(msg['payload'])
      temp.flush()


      try:
        output = subprocess.check_output(path, stderr=subprocess.STDOUT)
      except subprocess.CalledProcessError as e:
        raise Exception("Error: {0}".format(e))

    return {
        'label': msg['response_id'],
        'payload': output
        }

  def handle(self, msg):
    if msg['request'] == 'validate':
      return self.validate(msg)
    else:
      raise

def instantiate():
  return LobsterDomain()
