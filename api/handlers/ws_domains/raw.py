import logging
logger = logging.getLogger(__name__)

import restful
import api.handlers.ws_domains as ws_domains
import api
import hashlib
import os
import re
import sys

import pprint

from subprocess import *

class RawDomain(object):

    def __init__(self):
        print "Raw.__init__"

    @staticmethod
    def createNode(node_type, name, rules, policy, selected):
		return {
			'type': node_type,
			'name': name,
			'rules': rules,
			'policy': policy,
			'selected': selected
			}

    @staticmethod
    def nodesFromRules(rules, policyid, nodeMap, linksMap):
    	for r in rules:
            new_subject_node = new_object_node = new_class_node = new_perm_node = None

            r['policy'] = policyid

            # Find existing node if it exists
            curr_subject_node = nodeMap.get("subject-" + r['subject'], None)
            curr_object_node = nodeMap.get("object-" + r['object'], None)
            curr_class_node = nodeMap.get("class-" + r['class'], None)
            curr_perm_node = nodeMap.get("perm-" + r['perm'], None)

            # If node exists then update it, else create a new one
            if curr_subject_node:
                if r in curr_subject_node['rules']:
                    curr_subject_node['rules'].append(r)
            else:
                new_subject_node = RawDomain.createNode("subject", r['subject'], [r], policyid, True)
                nodeMap["subject-" + r['subject']] = new_subject_node
            if curr_object_node:
                if r in curr_object_node['rules']:
                    curr_object_node['rules'].append(r)
            else:
                new_object_node = RawDomain.createNode("object", r['object'], [r], policyid, True)
                nodeMap["object-" + r['object']] = new_object_node
            if curr_class_node:
                if r in curr_class_node['rules']:
                    curr_class_node['rules'].append(r)
            else:
                new_class_node = RawDomain.createNode("class", r['class'], [r], policyid, True)
                nodeMap["class-" + r['class']] = new_class_node
            if curr_perm_node:
                if r in curr_perm_node['rules']:
                    curr_perm_node['rules'].append(r)
            else:
                new_perm_node = RawDomain.createNode("perm", r['perm'], [r], policyid, True)
                nodeMap["perm-" + r['perm']] = new_perm_node

            RawDomain.generateLink(curr_perm_node, curr_object_node, new_perm_node, new_object_node, linksMap, r, policyid)
            RawDomain.generateLink(curr_subject_node, curr_perm_node, new_subject_node, new_perm_node, linksMap, r, policyid)
            RawDomain.generateLink(curr_object_node, curr_class_node, new_object_node, new_class_node, linksMap, r, policyid)
            RawDomain.generateLink(curr_perm_node, curr_class_node, new_perm_node, new_class_node, linksMap, r, policyid)

    @staticmethod
    def generateLink(curr_source_node, curr_target_node, new_source_node, new_target_node, linksMap, r, policyid):
        if curr_source_node and not curr_target_node:
            source = curr_source_node
            target = new_target_node
            rules = {v['subject']+'-'+v['object']+'-'+v['perm']+'-'+v['class']:v for v in target['rules'] + source['rules']}.values()
            link = {'source': source, 'target': target, 'rules': rules, 'policy': policyid}
            linksMap[source['type'] + '-' + source['name'] + '-' + target['type'] + '-' + target['name']] = link
        elif not curr_source_node and curr_target_node:
            source = new_source_node
            target = curr_target_node
            rules = {v['subject']+'-'+v['object']+'-'+v['perm']+'-'+v['class']:v for v in target['rules'] + source['rules']}.values()
            link = {'source': source, 'target': target, 'rules': rules, 'policy': policyid}
            linksMap[source['type'] + '-' + source['name'] + '-' + target['type'] + '-' + target['name']] = link
        elif not curr_source_node and not curr_target_node:
            source = new_source_node
            target = new_target_node
            rules = {v['subject']+'-'+v['object']+'-'+v['perm']+'-'+v['class']:v for v in target['rules'] + source['rules']}.values()
            link = {'source': source, 'target': target, 'rules': rules, 'policy': policyid}
            linksMap[source['type'] + '-' + source['name'] + '-' + target['type'] + '-' + target['name']] = link
        else:
            source = curr_source_node
            target = curr_target_node
            link_key = source['type'] + '-' + source['name'] + '-' + target['type'] + '-' + target['name']
            if link_key in linksMap:
                link = linksMap[source['type'] + '-' + source['name'] + '-' + target['type'] + '-' + target['name']]
            else:
                link = None

        if link:
            if r in link['rules']:
                link['rules'].append(r)
        else:
            # Source and target were previously found in two separate rules
            link = {'source': source, 'target': target, 'rules': [r], 'policy': policyid}
            linksMap[source['type'] + '-' + source['name'] + '-' + target['type'] + '-' + target['name']] = link

    def parse(self, msg):
        """ Given a set of parameters of the form, return the
        JSON for the raw module.
        """

        raw = msg['payload']['text']
        del msg['payload']['text']
        raw_hash = hashlib.md5(raw).hexdigest()

        refpol_id = msg['payload']['policy']
        del msg['payload']['policy']

        refpol_id = api.db.idtype(refpol_id)
        refpol = ws_domains.call('refpolicy', 'Read', refpol_id)

        logger.info("WS:validate?%s" % "&".join(
            ["{0}={1}".format(x, y) for x, y in msg['payload'].iteritems() if x != 'text']))

        # If the raw is identical, and the parameters are identical, just return the one we already
        # translated.
        if (refpol.parsed and False
                and refpol.documents['raw']['digest'] == raw_hash
                and refpol.parsed['params'] == msg['payload']['params']):

            logger.info("Returning cached JSON")

            return {
                'label': msg['response_id'],
                'payload': api.db.json.dumps(refpol.parsed)
            }

        else:

            table = []

            # Need to get the parsed data for all the modules
            # Use ws_domains.call() to invoke raw.py and get the raw policy
            line_num = 0
            print("----------------------")
            print(len(raw.splitlines()))
            print("----------------------")
            for line in raw.splitlines():
                line_num += 1
                # Split on ":"
                rule = line.strip().split(":")

                lside = rule[0].lstrip("allow").strip()
                rside = rule[1].strip()

                if lside.find("{") == -1:
                    # Should be "subj_t obj_t;"
                    subj_t = lside.split(" ")[0]
                    obj_t = lside.split(" ")[1]
                elif lside.find("{") < lside.find(" "):
                    # We have a list of subjects
                    subj_t = lside[lside.find("{")+1:lside.find("}")].strip()
                    if lside.find("}") == lside.rfind("}"):
                        # {subj_t1 subj_t2} obj_t;
                        obj_t = lside.split("}")[1].rstrip(";").strip()
                    else:
                        # {subj_t1 subj_t2} {obj_t1 obj_t2};
                        obj_t = lside[lside.rfind("{")+1:lside.rfind("}")].strip()
                else:
                    # subj_t {obj_t1 obj_t2};
                    subj_t = lside.split("{")[0].strip()
                    obj_t = lside[lside.find("{")+1:lside.find("}")].strip()

                if rside.find("{") == -1:
                    # Should be "obj_c perm;"
                    obj_c = rside.split(" ")[0]
                    perms = rside.split(" ")[1].rstrip(";")
                elif rside.find("{") < rside.find(" "):
                    # We have a list of classes
                    obj_c = rside[rside.find("{")+1:rside.find("}")].strip()
                    if rside.find("}") == rside.rfind("}"):
                        # {obj_c1 obj_c2} permission;
                        perms = rside.split("}")[1].rstrip(";").strip()
                    else:
                        # {obj_c1 obj_c2} {perm1 perm2};
                        perms = rside[rside.rfind("{")+1:rside.rfind("}")].strip()
                else:
                    # obj_c {perm1 perm2};
                    obj_c = rside.split("{")[0].strip()
                    perms = rside[rside.find("{")+1:rside.find("}")].strip()

                for s in subj_t.split(" "):
                    for ot in obj_t.split(" "):
                        for oc in obj_c.split(" "):
                            for p in perms.split(" "):
                                row = {"subject":s, "object":ot, "class":oc, "perm":p, "rule": line.strip()}
                                table.append(row)

            node_map = {}
            link_map = {}
            RawDomain.nodesFromRules(table, refpol.id, node_map, link_map)

            refpol['parsed'] = {
                'version': '1.0',
                'errors': [],
                'parameterized': {"rules": table},
                'params': msg['payload']['params']
            }
            logger.info("Size of node_map: {0}".format(sys.getsizeof(node_map)))
            logger.info("Size of link_map: {0}".format(sys.getsizeof(link_map)))
            myctr = 0
            for k in node_map.iterkeys():
                if myctr == 0:
                    pprint.pprint(node_map[k])
                node_map[k].pop('rules', None)
                if myctr == 0:
                    pprint.pprint(node_map[k])
                myctr += 1
            myctr = 0
            for v in link_map.itervalues():
                if myctr == 0:
                    pprint.pprint(v)
                v.pop('rules', None)
                if myctr == 0:
                    pprint.pprint(v)
                myctr += 1
            logger.info("Size of node_map: {0}".format(sys.getsizeof(node_map)))
            logger.info("Size of link_map: {0}".format(sys.getsizeof(link_map)))
            print("=====================")
            print("Pre insert")
            print("=====================")

            refpol.Insert()
            print("=====================")
            print("Post insert")
            print("=====================")

        return {
            'label': msg['response_id'],
            'payload': api.db.json.dumps(refpol.parsed)
        }

    def translate_selinux(self, params):
        """ Given a set of parameters of the form, return the
        JSON for the raw module.

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
        # output = self._make_request('POST', '/import/selinux',
        #                             params if isinstance(params, basestring) else api.db.json.dumps(params))

        # exec_str = "./ide/tools/te2json.py"
        # exec_str += " -j -t -i"
        # #filename = "~/Documents/V3SPA/ide/tools/" + (params['filename'] if params['filename'] else "apache.te")
        # filename = params['module']['te_file']
        # exec_str += " " + filename
        # output = Popen([exec_str], stdout=PIPE, shell=True).communicate()[0]

        with open(params['module']['te_file'], 'r') as myfile:
            data = myfile.read()

        return {
            "result": data,
            "errors": []
        }

    def handle(self, msg):
        if msg['request'] == 'parse':
            return self.parse(msg)
        else:
            raise Exception("Invalid message type for 'raw' domain")


def __instantiate__():
    return RawDomain()

