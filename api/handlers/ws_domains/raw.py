import logging
logger = logging.getLogger(__name__)

import restful
import api.handlers.ws_domains as ws_domains
import api
import hashlib

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
        if (refpol.parsed
                and refpol.documents['raw']['digest'] == raw_hash
                and refpol.parsed['params'] == msg['payload']['params']):

            logger.info("Returning cached JSON")

            return {
                'label': msg['response_id'],
                'payload': api.db.json.dumps(refpol.parsed)
            }

        else:

            for modname in refpol['modules']:
                # Use ws_domains.call() to invoke raw.py and get the raw policy
                module = refpol['modules'][modname]

            exec_str = "./ide/tools/te2json.py"
            exec_str += " -j -t -i"
            #filename = "~/Documents/V3SPA/ide/tools/" + (params['filename'] if params['filename'] else "apache.te")
            filename = module['te_file']
            exec_str += " " + filename
            output = Popen([exec_str], stdout=PIPE, shell=True).communicate()[0]

            refpol['parsed'] = {
                'version': '1.0',
                'errors': [],
                'parameterized': api.db.json.loads(output),
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

