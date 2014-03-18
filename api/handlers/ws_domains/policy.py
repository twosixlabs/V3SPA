import logging
logger = logging.getLogger(__name__)

import restful
import refpolicy
import api.handlers.ws_domains as ws_domains
import api


class Policy(restful.ResourceDomain):
    TABLE = 'policies'

    @classmethod
    def do_create(cls, params, response):
        refpol = refpolicy.RefPolicy.Read(params['refpolicy_id'])

        modname, version = refpolicy.extract_module_version(
            params['documents']['te'])

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

        if 'refpolicy_id' in params:
          params['refpolicy_id'] = api.db.idtype(params['refpolicy_id'])

        refpol = refpolicy.RefPolicy.Read(params['refpolicy_id'])
        dynamic_policy = cls.Read(params)

        # If the dynamic_policy is none, that means that it's a module
        # belonging to the reference policy, but hasn't been edited before.
        if dynamic_policy is None:

            dynamic_policy_data = {
                'id': params['id'],
                'refpolicy_id': params['refpolicy_id'],
                'documents':
                refpolicy.read_module_files(
                    refpol['modules'][params['id']],
                    editable=False),
                'type': 'selinux'
            }

            dynamic_policy = cls(dynamic_policy_data)


        if 'dsl' not in dynamic_policy['documents']:
          translate_args = {
              'refpolicy': refpol.id,
              'modules': [{
                  'name': params['id'],
                  'if': dynamic_policy['documents'].get('if', "")['text'],
                  'te': dynamic_policy['documents'].get('te', "")['text'],
                  'fc': dynamic_policy['documents'].get('fc', "")['text']
              }]
          }

          dsl = ws_domains.call('lobster', 'translate_selinux', translate_args)

          dynamic_policy['documents']['dsl'] = {
              'text': dsl['result'],
              'mode': 'lobster'
          }

          dynamic_policy.Insert()

        response['payload'] = dynamic_policy
        return response


def __instantiate__():
    return Policy
