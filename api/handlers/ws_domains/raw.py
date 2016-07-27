import logging
logger = logging.getLogger(__name__)

import restful
import refpolicy
import api.handlers.ws_domains as ws_domains
import api
import hashlib
import os
import re
import sys

import api.jsonh

from subprocess import *

class RawDomain(object):

    def __init__(self):
        print "Raw.__init__"

    @staticmethod
    def createNode(node_type, name):
    	# """ Create a new node.
    	# t: The type of the node (subject, object, class, or perm).
    	# n: The name of the node (system_server, read, file, etc.).
    	# l: A list of links for all other nodes that occur in the the same allow
    	# rules as this node. E.g. if this node is a subject, it will include
    	# all links subject->perm, perm->object, perm->class, and object->class
    	# for all permissions, objects, and classes that also occured in an allow
    	# rule with this subject.
    	# """

		return {
			't': node_type,
			'n': name,
			'l': set()
			}

    @staticmethod
    def createLink(source, target):
        return {
            's': source,
            't': target
            }

    @staticmethod
    def append_new_links_to_node(curr_idx, new_idx, node_list, new_links):
        idx = curr_idx if curr_idx >= 0 else new_idx
        node_list[idx]['l'] |= set(new_links)

    @staticmethod
    def nodesFromRules(rules, policyid, nodeMap, linkMap, nodeList, linkList):
    	for r in rules:
            new_subject_node = new_object_node = new_class_node = new_perm_node = None

            r['policy'] = policyid

            # Find existing node if it exists
            curr_subject_node = nodeMap.get("subject-" + r['subject'], -1)
            curr_object_node = nodeMap.get("object-" + r['object'], -1)
            curr_class_node = nodeMap.get("class-" + r['class'], -1)
            curr_perm_node = nodeMap.get("perm-" + r['perm'], -1)

            # If node exists then update it, else create a new one
            if curr_subject_node >= 0:
                None
            else:
                nodeMap["subject-" + r['subject']] = len(nodeList)
                new_subject_node = len(nodeList)
                nodeList.append(RawDomain.createNode("s", r['subject']))
            if curr_object_node >= 0:
                None
            else:
                nodeMap["object-" + r['object']] = len(nodeList)
                new_object_node = len(nodeList)
                nodeList.append(RawDomain.createNode("o", r['object']))
            if curr_class_node >= 0:
                None
            else:
                nodeMap["class-" + r['class']] = len(nodeList)
                new_class_node = len(nodeList)
                nodeList.append(RawDomain.createNode("c", r['class']))
            if curr_perm_node >= 0:
                None
            else:
                nodeMap["perm-" + r['perm']] = len(nodeList)
                new_perm_node = len(nodeList)
                nodeList.append(RawDomain.createNode("p", r['perm']))

            new_links = []

            RawDomain.generateLink(curr_perm_node, curr_object_node, new_perm_node, new_object_node, nodeList, linkMap, linkList, new_links)
            RawDomain.generateLink(curr_subject_node, curr_perm_node, new_subject_node, new_perm_node, nodeList, linkMap, linkList, new_links)
            RawDomain.generateLink(curr_object_node, curr_class_node, new_object_node, new_class_node, nodeList, linkMap, linkList, new_links)
            RawDomain.generateLink(curr_perm_node, curr_class_node, new_perm_node, new_class_node, nodeList, linkMap, linkList, new_links)

            RawDomain.append_new_links_to_node(curr_subject_node, new_subject_node, nodeList, new_links)
            RawDomain.append_new_links_to_node(curr_object_node, new_object_node, nodeList, new_links)
            RawDomain.append_new_links_to_node(curr_class_node, new_class_node, nodeList, new_links)
            RawDomain.append_new_links_to_node(curr_perm_node, new_perm_node, nodeList, new_links)

    @staticmethod
    def generateLink(curr_source_node, curr_target_node, new_source_node, new_target_node, nodeList, linkMap, linkList, new_links):
        if curr_source_node >= 0 and curr_target_node == -1:
            source = curr_source_node
            target = new_target_node
            s_node = nodeList[source]
            t_node = nodeList[target]
            link = RawDomain.createLink(source, target)
            link_idx = len(linkList)
            linkMap[s_node['t'] + '-' + s_node['n'] + '-' + t_node['t'] + '-' + t_node['n']] = link_idx
            linkList.append(link)
            new_links.append(link_idx)
        elif curr_source_node == -1 and curr_target_node >= 0:
            source = new_source_node
            target = curr_target_node
            s_node = nodeList[source]
            t_node = nodeList[target]
            link = RawDomain.createLink(source, target)
            link_idx = len(linkList)
            linkMap[s_node['t'] + '-' + s_node['n'] + '-' + t_node['t'] + '-' + t_node['n']] = link_idx
            linkList.append(link)
            new_links.append(link_idx)
        elif curr_source_node == -1 and curr_target_node == -1:
            source = new_source_node
            target = new_target_node
            s_node = nodeList[source]
            t_node = nodeList[target]
            link = RawDomain.createLink(source, target)
            link_idx = len(linkList)
            linkMap[s_node['t'] + '-' + s_node['n'] + '-' + t_node['t'] + '-' + t_node['n']] = link_idx
            linkList.append(link)
            new_links.append(link_idx)
        else:
            source = curr_source_node
            target = curr_target_node
            s_node = nodeList[source]
            t_node = nodeList[target]
            link_key = s_node['t'] + '-' + s_node['n'] + '-' + t_node['t'] + '-' + t_node['n']
            if link_key in linkMap:
                link_idx = linkMap[link_key]
                link = linkList[link_idx]
                new_links.append(link_idx)
            else:
            	link = None

        if link:
        	None
        else:
            # Source and target were previously found in two separate rules
            link = RawDomain.createLink(source, target)
            link_idx = len(linkList)
            linkMap[s_node['t'] + '-' + s_node['n'] + '-' + t_node['t'] + '-' + t_node['n']] = link_idx
            linkList.append(link)
            new_links.append(link_idx)
            

    @staticmethod
    def condensedNodesFromRules(rules, nodeMap, linkMap, nodeList, linkList):
    	for r in rules:
    		source_key = r['subject']
    		target_key = r['object'] + '.' + r['class']
    		link_key = source_key + '-' + target_key
    		source_node = nodeMap.get(source_key, -1)
    		target_node = nodeMap.get(target_key, -1)

    		if source_node == -1:
    			# Create the node
    			new_source = { 'n': source_key }
    			source_node = len(nodeList)
    			nodeMap[source_key] = source_node
    			nodeList.append(new_source)
    		if target_node == -1:
    			# Create the node
    			new_target = { 'n': target_key }
    			target_node = len(nodeList)
    			nodeMap[target_key] = target_node
    			nodeList.append(new_target)

    		link = linkMap.get(link_key, -1)
    		# If the link doesn't exist, create it
    		if link == -1:
    			link = {
    				's': source_node,
    				't': target_node,
    				'p': [r['perm']]
    			}
    			linkMap[link_key] = link
    			linkList.append(link)
    		# If it exists, update the permissions list if necessary
    		elif r['perm'] not in link['p']:
    			link['p'].append(r['perm'])

    def fetch_rules(self, msg):
        """ Return the allow rules that match the given subject, object, class,
        and permission. Each of the "params" is optional. Only returns rules
        that match all the given params.

            {
              "payload":
                {
                    "policy": ["policyid1", "policyid2", ...]
                    "params":
                    	{
                    		"subject": "(optional) name of subject"
                    		"object": "(optional) name of object"
                    		"class": "(optional) name of class"
                    		"perm": "(optional) name of permission"
                    	}
                }
            }
        """

        # msg.payload.policy is the id
        refpol_id_arr = msg['payload']['policy']

        found_rules = {}

        for refpol_id in refpol_id_arr:

	        refpol_id = api.db.idtype(refpol_id)
	        logger.info("Starting read: {0}".format(refpol_id))
	        refpol = refpolicy.RefPolicy.Find({'_id': refpol_id}, {'parsed': True, 'id': True, '_id': True}, 1)[0]
	        logger.info("Finished read")


	        # If already parsed, just return the one we already translated.
	        if ('parsed' in refpol
	        	and 'parameterized' in refpol['parsed']
	        	and 'rules' in refpol['parsed']['parameterized']):
	            logger.info("Looking up rules")

	            subj = msg['payload']['params'].get('subject', None)
	            obj = msg['payload']['params'].get('object', None)
	            cls = msg['payload']['params'].get('class', None)
	            perm = msg['payload']['params'].get('perm', None)

	            match_dict = msg['payload']['params']

	            # Invalid request, so skip this policy
	            if not (subj or obj or cls or perm):
	            	continue

	            rules = refpol['parsed']['parameterized']['rules']

	            for r in rules:
	            	include_rule = True
	            	for k in match_dict:
	            		if match_dict[k] != r[k]:
	            			include_rule = False
	            	if include_rule:
	            		if r['rule'] in found_rules:
	            			found_rules[r['rule']]['policy'] = 'both'
	            		else:
	            			found_rules[r['rule']] = { 'rule': r['rule'], 'policy': refpol['id'] }

	        else:
	        	logger.info("Policy {0} has not been parsed".format(refpol_id))


        # Return the unique rules from the list
        return {
            'label': msg['response_id'],
            'payload': api.db.json.dumps(found_rules.values())
        }

    def fetch_condensed_graph(self, msg):
        """ Return JSON for the nodes and links of the raw policy rules.
        This is a condensed format where <subject> and <object>.<class>
        are nodes, and permissions are links between them.
        """

        # msg.payload.policy is the id
        refpol_id = msg['payload']['policy']
        #del msg['payload']['policy']

        refpol_id = api.db.idtype(refpol_id)
        refpol = ws_domains.call('refpolicy', 'Read', refpol_id)

        # If already parsed, just return the one we already translated.
        if ('parsed' in refpol
        	and 'parameterized' in refpol['parsed']
        	and 'rules' in refpol['parsed']['parameterized']):
            logger.info("Returning cached condensed graph JSON")
        else:
            # Parse the policy
            ws_domains.call('raw', 'parse', msg)
            # Read the policy again
            refpol = ws_domains.call('refpolicy', 'Read', refpol_id)

        if (not 'condensed' in refpol['parsed']['parameterized']):

            # Build the node and link lists from the rules table
            rules = refpol['parsed']['parameterized']['rules']
            node_map = {}
            link_map = {}
            node_list = []
            link_list = []
            RawDomain.condensedNodesFromRules(rules, node_map, link_map, node_list, link_list)

            # Sparsify/compress the dicts/JSON objects
            node_list = api.jsonh.dumps(node_list)
            link_list = api.jsonh.dumps(link_list)

            refpol['parsed']['parameterized']['condensed'] = {
            	'nodes': node_list,
            	'links': link_list
            }

            refpol.Insert()

        # Don't send the rules or raw to the client
        refpol['parsed']['parameterized'].pop('rules', None)
        refpol['parsed']['parameterized'].pop('raw', None)
        refpol['parsed']['parameterized'].pop('condensed_lobster', None)

        return {
            'label': msg['response_id'],
            'payload': api.db.json.dumps(refpol.parsed)
        }


    @staticmethod
    def build_node_link_map(rules, policyid, nodeMap, linkMap, nodeList, linkList):
    	""" Builds a dict that maps node names to the list of links.
    	"""
    	print("build_node_link_map")

    def fetch_raw_graph(self, msg):
        """ Return JSON for the nodes and links of the raw policy rules.
        """

        # msg.payload.policy is the id
        refpol_id = msg['payload']['policy']
        #del msg['payload']['policy']

        refpol_id = api.db.idtype(refpol_id)
        refpol = ws_domains.call('refpolicy', 'Read', refpol_id)

        # If already parsed, just return the one we already translated.
        if ('parsed' in refpol
        	and 'parameterized' in refpol['parsed']
        	and'rules' in refpol['parsed']['parameterized']):
            logger.info("Returning cached JSON")
        else:
            # Parse the policy
            ws_domains.call('raw', 'parse', msg)
            # Read the policy again
            refpol = ws_domains.call('refpolicy', 'Read', refpol_id)

        if (not 'raw' in refpol['parsed']['parameterized']):

            # Build the node and link lists from the rules table
            rules = refpol['parsed']['parameterized']['rules']
            node_map = {} # Maps a node name to its list index
            link_map = {} # Maps a link name to its list index
            node_list = [] # List of nodes
            link_list = [] # List of links
            RawDomain.nodesFromRules(rules, refpol.id, node_map, link_map, node_list, link_list)
            for node in node_list:
            	node['l'] = list(node['l'])

            # Sparsify/compress the dicts/JSON objects
            node_list = api.jsonh.dumps(node_list)
            link_list = api.jsonh.dumps(link_list)

            refpol['parsed']['parameterized']['raw'] = {
            	'nodes': node_list,
            	'links': link_list
            }

            refpol.Insert()

        # Don't send the rules or condensed graph to the client
        refpol['parsed']['parameterized'].pop('rules', None)
        refpol['parsed']['parameterized'].pop('condensed', None)
        refpol['parsed']['parameterized'].pop('condensed_lobster', None)

        return {
            'label': msg['response_id'],
            'payload': api.db.json.dumps(refpol.parsed)
        }

    def parse(self, msg):
        """ Given a set of parameters of the form, return the
        JSON for the raw module.
        """

        # msg.payload.policy is the id
        refpol_id = msg['payload']['policy']
        del msg['payload']['policy']

        refpol_id = api.db.idtype(refpol_id)
        refpol = ws_domains.call('refpolicy', 'Read', refpol_id)

        # If already parsed, just return the one we already translated.
        if ('parsed' in refpol
        	and 'parameterized' in refpol['parsed']
        	and 'rules' in refpol['parsed']['parameterized']):
            logger.info("Returning cached JSON")

        else:

            raw = refpol['documents']['raw']['text']

            table = []

            # Need to get the parsed data for all the modules
            # Use ws_domains.call() to invoke raw.py and get the raw policy
            line_num = 0
            logger.info("Parsing {0} rule lines".format(len(raw.splitlines())))
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

            if 'parsed' not in refpol:
                refpol['parsed'] = {
                    'version': '1.0',
                    'errors': [],
                    'parameterized': {}
                }

            refpol['parsed']['parameterized']['rules'] = table

            print("=====================")
            print("Pre insert")
            print("=====================")

            refpol.Insert()
            print("=====================")
            print("Post insert")
            print("=====================")

        # Don't send the rules to the client
        refpol['parsed']['parameterized'].pop('rules', None)

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
        elif msg['request'] == 'fetch_raw_graph':
            return self.fetch_raw_graph(msg)
        elif msg['request'] == 'fetch_condensed_graph':
            return self.fetch_condensed_graph(msg)
        elif msg['request'] == 'fetch_rules':
            return self.fetch_rules(msg)
        else:
            raise Exception("Invalid message type for 'raw' domain")


def __instantiate__():
    return RawDomain()

