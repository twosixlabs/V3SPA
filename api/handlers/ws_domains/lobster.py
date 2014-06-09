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

        logging.debug("Fetching {0} from v3spa-server".format(backend_uri))

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

    @staticmethod
    def get_annotation(hop, *names, **kw):
        param = kw.get('annotation_param', 'annotations')
        notes = filter(lambda x: x['name'] in names, hop[param])
        if len(notes):
            return notes
        else:
            return None

    def path_walk(self, path, data, origin, lobster_data):

        previous_dom = None
        new_path = []
        expanded_ids = data['domains'].keys()
        last_perm = None

        for i, hop_id in enumerate(map(str, path)):

            hop = data['connections'][hop_id]

            fwd = 'right' if hop['left_dom'] == origin else 'left'

            tried_expanding = False
            while True:
                try:
                    next_domain = data['domains'][hop[fwd + "_dom"]]
                    from_dom = data['domains'][
                        hop['left_dom' if fwd == 'right' else 'right_dom']]
                    dest_port = data['ports'][hop[fwd]]
                except KeyError:
                    if tried_expanding is True:
                      raise Exception("Couldn't expand the graph to link from {0}"
                                      .format(next_domain))
                    else:
                      tried_expanding = True

                    # We don't have the data locally. Figure out how to find
                    # it.
                    if previous_dom is not None and previous_dom['parent'] == '0':
                        # We're at the root. Here an annotation can tell us
                        # where the path goes.
                        filter_key = 'Lhs' if fwd == 'left_dom' else 'Rhs'
                        annotations = filter(lambda x: x['name'] == filter_key,
                                             hop['annotations'])
                    else:
                        annotations = []

                    expanded_ids.append(hop[fwd + '_dom'])
                    output = self._make_request(
                        'POST', '/parse?{1}&{0}'.format(
                            "&".join(["id={0}".format(hid)
                                     for hid in expanded_ids]),
                            "&".join(["path={0}".format(".".join(a['args']))
                                      for a in annotations])),
                        lobster_data)

                    result = api.db.json.loads(output.body)
                    data['domains'].update(result['result']['domains'])
                    data['connections'].update(result['result']['connections'])
                    data['ports'].update(result['result']['ports'])
                else:
                    break

            is_type = self.get_annotation(
                next_domain, 'Type', annotation_param='domainAnnotations')

            if i == 0:
                new_path.append({
                    'type': 'origin',
                    'name': from_dom['path'],
                    'hop': hop_id
                })
                print("Origin: {0}".format(from_dom['path']))
            elif (next_domain['class'] == 'Domtrans_pattern'
                    and next_domain != previous_dom):
                attr = self.get_annotation(
                    next_domain, "Macro", annotation_param='domainAnnotations')
                new_path.append({
                    'hop': hop_id,
                    'type': 'transition',
                    'name': attr[0]['args'][1]
                })
                print("Can transition via {0}".format(attr[0]['args'][1]))
            # This is attribute membership connection:
            elif self.get_annotation(hop, 'Attribute'):
                if fwd == 'left':
                    fwd_arg = filter(lambda x: x['name'] == 'Lhs',
                                     hop['annotations'])
                else:
                    fwd_arg = filter(lambda x: x['name'] == 'Rhs',
                                     hop['annotations'])

                if (fwd_arg and fwd_arg[0]['args'][1] == 'attribute_subj') or \
                        dest_port['name'] == 'attribute_subj':
                    print("which is a member of")
                    new_path.append({
                        'hop': hop_id,
                        'type': 'member_of',
                    })
                elif fwd_arg and fwd_arg[0]['args'][1] == 'member_obj' or \
                        dest_port['name'] == 'member_obj':
                    print("an attribute that contains")
                    new_path.append({
                        'hop': hop_id,
                        'type': 'attribute_contains',
                    })
                elif dest_port['name'] == 'attribute_subj':
                    import pdb
                    pdb.set_trace()
            elif (next_domain['class'] != 'Domtrans_pattern'
                  and self.get_annotation(hop, 'Perm')):
                last_perm = [
                    (x['args'][0], dest_port['name'])
                    for x in self.get_annotation(hop, 'Perm')
                    ]
                print("which has {0} permissions ".format(last_perm))
                new_path.append({
                    'hop': hop_id,
                    'type': 'permission',
                    'name': last_perm,
                    'class': dest_port['name']
                })
            else:
                pass
                #import pdb; pdb.set_trace()
                #print("Don't know what this hop is: {0}".format(hop))

            if is_type:
                new_path.append({
                    'hop': hop_id,
                    'type': 'type',
                    'name': next_domain['path']
                })
                new_path[-1]['class'] = dest_port['name']
                print("To '{1}' objects of type '{0}'"
                      .format(next_domain['path'], dest_port['name']))
            elif self.get_annotation(
                    next_domain, 'Attribute',
                    annotation_param='domainAnnotations'):
                new_path.append({
                    'hop': hop_id,
                    'type': 'attribute',
                    'name': next_domain['path']
                })
                if dest_port['name'] == 'attribute_subj':
                    print("attribute {0}".format(next_domain['path']))
                else:
                    new_path[-1]['class'] = dest_port['name']
                    print("To '{1}' objects of attribute type '{0}'"
                          .format(next_domain['path'], dest_port['name']))
            else:
              pass

            if self.get_annotation(hop, 'CondExpr'):
                # print(
                    #"If '{0}' is set".format(
                        # self.get_annotation(hop, 'CondExpr')[0]['args']))
                new_path[-1]['condition'] = self.get_annotation(
                    hop, 'CondExpr')[0]['args']

            origin = hop[fwd + "_dom"]
            previous_dom = next_domain

        return new_path, last_perm

    def query_reachability(self, msg):
        """ Run a reachability test from a given domain """
        logger.info("WS:query_reachability?%s" % msg['payload']['params'])

        output = self._make_request(
            'POST', '/paths?{0}'.format(msg['payload']['params']),
            msg['payload']['text'])

        result = api.db.json.loads(output.body)['result']

        for dest, paths in result.iteritems():
            if dest == 'truncated':
                continue

            new_paths = {}
            for path in paths:
                logger.info('Gathering additional data for {0}'.format(path))
                import urlparse
                params = urlparse.parse_qs(msg['payload']['params'])

                path_data, final_perms = self.path_walk(
                    path,
                    self.last_parse_request['result'],
                    params['id'][0],
                    msg['payload']['text'])

                logger.info("Re-tabulated path data")

                for perm, obclass in final_perms:
                  new_paths[perm] = {
                      'hops': path,
                      'human': path_data,
                      'perm': perm,
                      'class': obclass,
                      'endpoint': path_data[-1]['name']
                  }

            result[dest] = new_paths

        return {
            'label': msg['response_id'],
            'payload': {'paths': result, 'data': self.last_parse_request}
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

        self.last_parse_request = jsondata
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
