import logging
logger = logging.getLogger(__name__)

import restful
import refpolicy


class Policy(restful.ResourceDomain):
    TABLE = 'policies'

    @classmethod
    def do_create(cls, params, response):
        refpol = refpolicy.RefPolicy.Read(params['refpolicy_id'])

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

    @classmethod
    def do_get(cls, params, response):
        import pdb
        pdb.set_trace()

        dynamic_policy = cls.Read(params)

        # If the dynamic_policy is none, that means that it's a module
        # belonging to the reference policy, but hasn't been edited before.
        if dynamic_policy is None:

            refpol = refpolicy.RefPolicy.Read(params['refpolicy_id'])
            dynamic_policy_data = {
                'id': params['id'],
                'refpolicy_id': params['refpolicy_id'],
                'files':
                refpolicy.read_module_files(
                    refpol['modules'][params['id']]),
                'type': 'selinux'
            }

            dynamic_policy = cls(dynamic_policy_data)

        response['payload'] = dynamic_policy
        return response


def __instantiate__():
    return Policy
