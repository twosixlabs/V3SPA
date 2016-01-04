import logging
logger = logging.getLogger(__name__)

import restful
import api.handlers.ws_domains as ws_domains
import api
import hashlib
import os

from subprocess import *

class RawDomain(object):

    def __init__(self):
        print "Raw.__init__"

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
        if (refpol.parsed and False # TODO: remove 'and False' to allow caching
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
            for modname in refpol['modules']:
                # Use ws_domains.call() to invoke raw.py and get the raw policy
                module = refpol['modules'][modname]
                with open(module['te_file'], 'r') as f:
                    line_num = 0
                    for line in f:
                        line_num += 1
                        if line.lstrip(' \t\n\r').startswith("allow"):
                            # Skip allow rules that do not have colons
                            if line.find(":") == -1:
                                continue

                            # Skip allow rules that do not have semicolons (e.g. multiline rules)
                            if line.find(";") == -1:
                                continue

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
                                            row = {"subject":s, "object":ot, "class":oc, "perm":p, "module":modname}
                                            row["directory"] = os.path.basename(os.path.dirname(f.name))
                                            row["rule"] = line.lstrip().rstrip('\n')
                                            table.append(row)

            # exec_str = "./ide/tools/te2json.py"
            # exec_str += " -j -t -i"
            # #filename = "~/Documents/V3SPA/ide/tools/" + (params['filename'] if params['filename'] else "apache.te")
            # filename = module['te_file']
            # exec_str += " " + filename
            # output = Popen([exec_str], stdout=PIPE, shell=True).communicate()[0]

            refpol['parsed'] = {
                'version': '1.0',
                'errors': [],
                'parameterized': {"rules": table},
                'params': msg['payload']['params']
            }

            refpol.Insert()

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

