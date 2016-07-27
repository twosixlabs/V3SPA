import api
import logging
logger = logging.getLogger(__name__)

from tornado import httpclient
import hashlib
import urllib

import api.support.decompose
import api.handlers.ws_domains as ws_domains

import api.jsonh

import json

__MIN_LSR_VERSION__ = 6


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
                logger.critical("Required lobster version {0} but server speaks {1}"
                                 .format(__MIN_LSR_VERSION__, self._lobster_version))

            logger.info("Connected to lobster backend server v{0}"
                         .format(self._lobster_version))
        except httpclient.HTTPError as e:
            if e.code == 599:
                raise Exception("backend:lobster - Unavailable")

            else:
                # Our request wasn't valid anyway, we just wanted a response
                pass

    @staticmethod
    def _make_request(method, path, payload=None, timeout=90.0):
        http_client = httpclient.HTTPClient()
        backend_uri = "http://{0}{1}".format(
            api.config.get('lobster_backend', 'uri'),
            path)

        logger.info("Fetching {0} from v3spa-server".format(backend_uri))

        try:
            if payload:
                output = http_client.fetch(
                    backend_uri,
                    method=method,
                    body=payload,
                    request_timeout=timeout
                )
            else:
                output = http_client.fetch(
                    backend_uri,
                    method=method,
                    request_timeout=timeout
                )
        except httpclient.HTTPError as e:
            if e.code == 599:
                logger.warning("Request timed out")
                raise Exception("backend:lobster - Unavailable")
            elif e.code == 500:
                logger.warning("Error during request - {0}".format(e.response.body))
                raise Exception("backend:lobster - {0}".format(e.response.body))
            else:
                logger.warning("Error during request - [{0}] {1}"
                               .format(e.code, e.message))
                if api.config.get('main', 'debug'):
                    raise Exception(
                        "Backend error: [{0}] {1}".format(e.code, e.message))
                else:
                    raise Exception("backend:lobster - Unspecified Error")
        else:
            logger.info("Request successful")
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
        import urlparse
        params = urlparse.parse_qs(data['params'])
        jsondata = data['parameterized']
        expanded_ids = params['id']
        last_perm = None
        last_object_class = None

        for i, hop_info in enumerate(path):

            hop = jsondata['connections'][hop_info['conn']]

            if hop_info['left'] == origin:
                fwd = 'right'
                bwd = 'left'
            else:
                fwd = 'left'
                bwd = 'right'

            tried_expanding = False
            while True:
                try:
                    next_domain = jsondata['domains'][hop_info[fwd]]
                    from_dom = jsondata['domains'][hop_info[bwd]]
                    dest_port = jsondata['ports'][hop[fwd]]
                except KeyError:
                    if tried_expanding is True:
                        raise Exception("Couldn't expand the graph to link from {0}"
                                        .format(hop_info[fwd]))
                    else:
                        tried_expanding = True

                    expanded_ids.append(hop_info[fwd])
                    output = self._make_request(
                        'POST', '/parse?{0}'.format(
                            "&".join(["id={0}".format(hid)
                                     for hid in expanded_ids])),
                        lobster_data)

                    result = api.db.json.loads(output.body)
                    jsondata['domains'].update(result['result']['domains'])
                    jsondata['connections'].update(result['result']['connections'])
                    jsondata['ports'].update(result['result']['ports'])
                else:
                    break

            is_type = self.get_annotation(
                next_domain, 'Type', annotation_param='domainAnnotations')

            if i == 0:
                new_path.append({
                    'type': 'origin',
                    'name': from_dom['path'],
                    'hop': hop_info['conn']
                })
                print("Origin: {0}".format(from_dom['path']))

            if (next_domain['class'] == 'Domtrans_pattern'
                    and next_domain != previous_dom):
                attr = self.get_annotation(
                    next_domain, "Macro", annotation_param='domainAnnotations')
                new_path.append({
                    'hop': hop_info['conn'],
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
                        'hop': hop_info['conn'],
                        'type': 'member_of',
                    })
                elif fwd_arg and fwd_arg[0]['args'][1] == 'member_obj' or \
                        dest_port['name'] == 'member_obj':
                    print("an attribute that contains")
                    new_path.append({
                        'hop': hop_info['conn'],
                        'type': 'attribute_contains',
                    })
                elif dest_port['name'] == 'attribute_subj':
                    logger.critical("Encountered unexpected case when walking path. "
                                   "This probably indicates a serious bug.")
                    pass
            elif (next_domain['class'] != 'Domtrans_pattern'
                  and self.get_annotation(hop, 'Perm')):

                perms = [x['args']
                         for x in self.get_annotation(hop, 'Perm')]


                print("which has {0} permissions ".format(perms))

                new_path.append({
                    'hop': hop_info['conn'],
                    'type': 'permission',
                    'name': perms
                })

                last_perm = new_path[-1]

            else:
                pass

            if is_type:
                new_path.append({
                    'hop': hop_info['conn'],
                    'type': 'type',
                    'name': next_domain['path']
                })
                if last_object_class is not None:
                    new_path[-1]['class'] = last_object_class
                    last_object_class = None

                print("type '{0}'"
                      .format(next_domain['path'], last_object_class))
            elif self.get_annotation(
                    next_domain, 'Attribute',
                    annotation_param='domainAnnotations'):
                new_path.append({
                    'hop': hop_info['conn'],
                    'type': 'attribute',
                    'name': next_domain['path']
                })
                if dest_port['name'] == 'attribute_subj':
                    print("attribute {0}".format(next_domain['path']))
                else:
                    if last_object_class is not None:
                        new_path[-1]['class'] = last_object_class
                        last_object_class = None

                    print("attribute type '{0}'"
                          .format(next_domain['path']))
            else:
                pass

            if self.get_annotation(hop, 'CondExpr'):
                new_path[-1]['condition'] = self.get_annotation(
                    hop, 'CondExpr')[0]['args']

            origin = hop_info[fwd]
            previous_dom = next_domain

        import urllib
        data['params'] = urllib.urlencode(params, doseq=True)
        return new_path, last_perm

    def query_reachability(self, msg):
        """ Run a reachability test from a given domain """
        logger.info("WS:query_reachability?%s" % msg['payload']['params'])

        refpol_id = msg['payload']['policy']
        del msg['payload']['policy']
        refpol_id = api.db.idtype(refpol_id)
        refpol = ws_domains.call('refpolicy', 'Read', refpol_id)

        output = self._make_request(
            'POST', '/paths?{0}'.format(msg['payload']['params']),
            msg['payload']['text'])

        result = api.db.json.loads(output.body)['result']

        if result is not None:
          for dest, paths in result.iteritems():
              if dest == 'truncated':
                  continue

              new_paths = {'dest_id': dest, 'perms': {}}
              for path in paths:
                  logger.info('Gathering additional data for {0}'.format(path))
                  import urlparse
                  params = urlparse.parse_qs(msg['payload']['params'])

                  path_data, final_perm = self.path_walk(
                      path,
                      refpol.parsed,
                      params['id'][0],
                      msg['payload']['text'])

                  logger.info("Re-tabulated path data")

                  new_paths['dest'] = path_data[-1]['name']
                  for klass, perm in final_perm['name']:
                      new_paths['perms'][perm] = {
                          'hops': path,
                          'human': path_data,
                          'perm': perm,
                          'class': klass,
                          'endpoint': path_data[-1]
                      }

              result[dest] = new_paths

        return {
            'label': msg['response_id'],
            'payload': {'paths': result, 'data': refpol.parsed}
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
        dsl = msg['payload']['text']
        del msg['payload']['text']
        dsl_hash = hashlib.md5(dsl).hexdigest()

        refpol_id = msg['payload']['policy']
        del msg['payload']['policy']

        refpol_id = api.db.idtype(refpol_id)
        refpol = ws_domains.call('refpolicy', 'Read', refpol_id)

        logger.info("WS:validate?%s" % "&".join(
            ["{0}={1}".format(x, y) for x, y in msg['payload'].iteritems() if x != 'text']))

        # If the DSL is identical, and the parameters are identical, just return the one we already
        # translated.
        if (refpol.parsed
                and refpol.documents['dsl']['digest'] == dsl_hash
                and refpol.parsed['params'] == msg['payload']['params']):

            logger.info("Returning cached JSON")

            return {
                'label': msg['response_id'],
                'payload': api.db.json.dumps(refpol.parsed)
            }

        else:

            output = self._make_request(
                'POST', '/parse?{0}'.format(msg['payload']['params']),
                dsl)

            jsondata = api.db.json.loads(output.body)
            if msg['payload']['hide_unused_ports'] is True:
                jsondata = self._filter_unused_ports(jsondata)

            refpol['parsed'] = {
                'version': jsondata['version'],
                'errors': jsondata['errors'],
                'parameterized': jsondata['result'],
                'params': msg['payload']['params']
            }

            # If this DSL is different, then we need to recalculate the 
            # summarized version, which is parsed with paths=*
            if (len(jsondata['errors']) == 0
              and 'summary' not in refpol.parsed
              or refpol.documents['dsl']['digest'] != dsl_hash):
                output = self._make_request( 'POST', '/parse?path=*', dsl)
                jsondata = api.db.json.loads(output.body)
                refpol.parsed['full'] = jsondata['result']
                if jsondata['result'] is not None:
                  refpol.parsed['summary'] = api.support.decompose.flatten_perms(jsondata['result'])
                  refpol.parsed['permset'] = [{'text': x, "id": x}
                                              for x
                                              in api.support.decompose.perm_set(
                                                jsondata['result'])]
                else:
                  refpol.parsed['summary'] = []
                  refpol.parsed['permset'] = []


            refpol.Insert()

        del refpol.parsed['full']
        return {
            'label': msg['response_id'],
            'payload': api.db.json.dumps(refpol.parsed)
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
        logger.info("Params: {0}".format(params))
        try:
            endpoint_uri = '/projects/{0}/import/selinux'.format(params['refpolicy'])
            payload = params if isinstance(params, basestring) else api.db.json.dumps(params)
            output = self._make_request('POST', endpoint_uri, payload)
            if len(api.db.json.loads(output.body)['errors']) > 0:
                raise Exception(output['errors'])

            endpoint_uri = '/projects/{0}/json'.format(params['refpolicy'])
            output = self._make_request('GET', endpoint_uri)
        except Exception as e:
            raise api.DisplayError("Unable to import policy: {0}".format(e.message))
        else:
            return output.body
        
    def fetch_graph(self, msg):
        """ Return the JSON graph for the given policy. Params of the form

            {
              "payload":
                {
                    "policy": "policyid"
                }
            }
        """
        logger.info("Params: {0}".format(msg))

        # Assume we have already run translate_selinux() during policy upload

        # msg.payload.policy is the id
        refpol_id = msg['payload']['policy']

        refpol_id = api.db.idtype(refpol_id)
        refpol = ws_domains.call('refpolicy', 'Read', refpol_id)

        if ('parsed' not in refpol or 'parameterized' not in refpol['parsed']
            or 'condensed_lobster' not in refpol['parsed']['parameterized']):

            lobster_json = api.db.json.loads(refpol['documents']['dsl']['text'])
            lobster_json = lobster_json['result']

            connections = lobster_json['connections']
            ports = lobster_json['ports']
            domains = lobster_json['domains']

            node_map = {}
            link_map = {}
            module_map = {}
            node_list = []
            link_list = []
            module_list = []
            for key in connections.keys():
                conn = connections[key]
                te_file = ""
                perm_list = []

                left_dom = domains[conn['left_dom']]
                right_dom = domains[conn['right_dom']]

                left_port = ports[conn['left']]
                right_port = ports[conn['right']]

                active_dom = left_dom
                inactive_dom = right_dom
                if right_port['name'] == 'active':
                    active_dom = right_dom
                    inactive_dom = left_dom

                for annot in conn['annotations']:
                    if annot['name'] == 'Perm':
                        perm_list.append(annot['args']) # [class, perm]
                    elif annot['name'] == 'SourcePos':
                        te_file = annot['args'][0]

                # Skip connections that do not have any permissions
                if len(perm_list) == 0:
                    continue

                # Skip this connection if one of the domains is not an Attribute or a Type
                bothAreTypesOrAttrs = True
                for dom in [left_dom, right_dom]:
                    validAnnots = []
                    for domAnnot in dom['domainAnnotations']:
                        if domAnnot['name'] == 'Attribute' or domAnnot['name'] == 'Type':
                            validAnnots.append(domAnnot)
                    if len(validAnnots) == 0:
                        bothAreTypesOrAttrs = bothAreTypesOrAttrs and False

                if not bothAreTypesOrAttrs:
                    continue

                mod_idx = module_map.get(active_dom['module'], -1)
                if (mod_idx == -1):
                    mod_idx = len(module_list)
                    module_map[active_dom['module']] = mod_idx
                    module_list.append(active_dom['module'])

                # Create/get the source node
                source_key = active_dom['name']
                source_idx = node_map.get(source_key, -1)
                if source_idx == -1:
                    source_node = { 'n': source_key, 'm': mod_idx }
                    source_idx = len(node_list)
                    node_map[source_key] = source_idx
                    node_list.append(source_node)

                # Loop over each class to create the object.class pairs
                for perm in perm_list:
                    mod_idx = module_map.get(inactive_dom['module'], -1)
                    if (mod_idx == -1):
                        mod_idx = len(module_list)
                        module_map[inactive_dom['module']] = mod_idx
                        module_list.append(inactive_dom['module'])

                    target_key = inactive_dom['name'] + '.' + perm[0]
                    target_idx = node_map.get(target_key, -1)
                    if target_idx == -1:
                        target_node = { 'n': target_key, 'm': mod_idx }
                        target_idx = len(node_list)
                        node_map[target_key] = target_idx
                        node_list.append(target_node)
                    link_key = source_key + '-' + target_key
                    link = link_map.get(link_key, -1)
                    if link == -1:
                        link = {
                            's': source_idx,
                            't': target_idx,
                            'p': [perm[1]]
                        }
                        link_map[link_key] = link
                        link_list.append(link)
                    elif perm[1] not in link['p']:
                        link['p'].append(perm[1])

            # Sparsify/compress the dicts/JSON objects
            node_list = api.jsonh.dumps(node_list)
            link_list = api.jsonh.dumps(link_list)
            module_list = module_list

            if 'parsed' not in refpol:
                refpol['parsed'] = {
                    'version': '1.0',
                    'errors': [],
                    'parameterized': {}
                }

            refpol['parsed']['parameterized']['condensed_lobster'] = {
                'modules': module_list,
                'nodes': node_list,
                'links': link_list
            }

            refpol.Insert()

        # Don't send the rules or raw to the client
        refpol['parsed']['parameterized'].pop('rules', None)
        refpol['parsed']['parameterized'].pop('raw', None)
        refpol['parsed']['parameterized'].pop('condensed', None)

        return {
            'label': msg['response_id'],
            'payload': api.db.json.dumps(refpol.parsed)
        }

        # Return the cached version if available

        return api.db.json.loads({})

    def parse(self, msg):
        """ Return the JSON graph for the given policy. Params of the form

            {
              "payload":
                {
                    "policy": "policyid"
                }
            }
        """
        logger.info("Params: {0}".format(msg))

        # msg.payload.policy is the id
        refpol_id = msg['payload']['policy']
        del msg['payload']['policy']

        refpol_id = api.db.idtype(refpol_id)
        refpol = ws_domains.call('refpolicy', 'Read', refpol_id)

        # If already parsed, just return the one we already translated.
        if ('parsed' in refpol
            and 'parameterized' in refpol['parsed']
            and 'lobster_rules' in refpol['parsed']['parameterized']):
            logger.info("Returning cached JSON")

        else:

            dsl_json = refpol['documents']['dsl']['text']

        # Return the cached version if available

        return {
            'label': msg['response_id'],
            'payload': api.db.json.dumps(refpol.parsed)
        }

        

    def handle(self, msg):
        if msg['request'] == 'validate':
            return self.validate(msg)
        elif msg['request'] == 'query_reachability':
            return self.query_reachability(msg)
        elif msg['request'] == 'fetch_graph':
            return self.fetch_graph(msg)
        else:
            raise Exception("Invalid message type for 'lobster' domain")


def __instantiate__():
    return LobsterDomain()
