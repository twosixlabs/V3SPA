import logging
logger = logging.getLogger(__name__)

import restful
import refpolicy


class Policy(restful.ResourceDomain):
    TABLE = 'policies'

    @classmethod
    def do_create(cls, params, response):
        refpol = refpolicy.RefPolicy.Read(params['refpolicy'])

        modname, version = refpolicy.extract_module_version(
            params['files']['te'])

        if modname in refpol['modules']:
            raise Exception("'{0}' is already a module in '{1}'".format(
                modname, refpol['id']))

        params['id'] = modname

        refpol['modules'][modname] = {
            'name': modname,
            'version': version,
            'te_file': None,
            'fc_file': None,
            'if_file': None
        }

        refpol.Update()

        policy = cls(params)
        response['payload'] = policy.Insert()
        return response


def __instantiate__():
    return Policy
