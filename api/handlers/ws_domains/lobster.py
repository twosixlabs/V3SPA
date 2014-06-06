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
    def _make_request(method, path, payload, timeout=30.0):
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

    def query_reachability(self, msg):
        """ Run a reachability test from a given domain """
        logger.info("WS:query_reachability?%s" % msg['payload']['params'])

        output = self._make_request(
            'POST', '/paths?{0}'.format(msg['payload']['params']),
            msg['payload']['text'])

        return {
            'label': msg['response_id'],
            'payload': output.body
        }

    def export_selinux(self, msg):
      """ Request that the server export the POSTed
      lobster file as an SELinux policy.
      """

      output = self._make_request(
          'POST', '/export/selinux', msg)

      jsondata = api.db.json.loads(output.body)

      return jsondata['result']

    def validate(self, msg):
        """ Validate a Lobster file received from the IDE
        """

        logger.info("WS:validate?%s" % "&".join(
          ["{0}={1}".format(x, y) for x, y in msg['payload'].iteritems() if x != 'text']))

        output = self._make_request(
            'POST', '/parse?{0}'.format(msg['payload']['params']),
            msg['payload']['text'])

        jsondata = api.db.json.loads(output.body)
        if msg['payload']['hide_unused_ports'] is True:
          jsondata = self._filter_unused_ports(jsondata)

        return {
            'label': msg['response_id'],
            'payload': api.db.json.dumps(jsondata)
        }

    def _filter_unused_ports(self, data):
        """ Filter out all of the ports which do not have a connection.
        This includes their references inside domains, as well as their
        presence in the port list. """
        if 'errors' in data and len(data['errors']) > 0:
          return data

        connected_ports = set()
        for ident, conn in data['result']['connections'].iteritems():
          connected_ports.add(conn['right'])
          connected_ports.add(conn['left'])

        for port in data['result']['ports'].keys():
          if port not in connected_ports:
            del data['result']['ports'][port]

        for domkey, domain in data['result']['domains'].iteritems():
          domain['ports'][:] = [p for p in domain['ports']
                                if p in connected_ports]

        return data

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
        elif msg['request'] == 'query_reachability':
            return self.query_reachability(msg)
        else:
            raise Exception("Invalid message type for 'lobster' domain")


def __instantiate__():
    return LobsterDomain()
