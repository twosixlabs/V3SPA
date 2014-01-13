import subprocess
import time
import tempfile
import pkg_resources

class LobsterDomain(object):
  """Docstring for LobsterDomain """

  def __init__(self):
    """@todo: to be defined """
    pass

  def validate(self, msg):
    """ Validate a Lobster file received from the IDE
    """

    with tempfile.NamedTemporaryFile() as temp:
      temp.write(msg['payload'])
      temp.flush()

      path = [pkg_resources.resource_filename('api.bin', 'lobster-json'),
              temp.name]

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
