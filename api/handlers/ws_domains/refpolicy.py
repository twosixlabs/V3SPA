import logging
logger = logging.getLogger(__name__)
import base64
import itertools
import os
import re
import hashlib
import sys

import restful
import api.handlers.ws_domains as ws_domains
import api

import subprocess
from subprocess import CalledProcessError


def iter_lines(fil_or_str):
  if isinstance(fil_or_str, (basestring)):
    fil_or_str = fil_or_str.split('\n')

  for line in fil_or_str:
    yield line


def extract_module_version(module_text):
    """ Extracts the name and version from a module TE file """
    mod_defn_re = re.compile(
        r'policy_module\((?P<name>[a-zA-Z0-9\.\/_-]+),\s*(?P<version>[0-9]+\.[0-9]+(:?\.[0-9]+)?)\)')

    for line in iter_lines(module_text):
      match = mod_defn_re.match(line)
      if match:
        return match.group('name'), match.group('version')

    else:  # no matches
      raise Exception(".te file had no module string")


def read_module_files(module_data, limit=None, **addl_props):
  """ Read the files belonging to a module from disk and return
  their data as a dictionary. """

  files = {}
  
  if 'te_file' in module_data:
    with open(module_data['te_file']) as fin:
      info = os.fstat(fin.fileno())
      handle = itertools.islice(fin, limit)
      files['te'] = {'text': "".join(handle)}
      files['te'].update(**addl_props)
      files['te']['size'] = info.st_size

  if 'if_file' in module_data:
    with open(module_data['if_file']) as fin:
      info = os.fstat(fin.fileno())
      handle = itertools.islice(fin, limit)
      files['if'] = {'text': "".join(handle)}
      files['if'].update(**addl_props)
      files['if']['size'] = info.st_size

  if 'fc_file' in module_data:
    with open(module_data['fc_file']) as fin:
      info = os.fstat(fin.fileno())
      handle = itertools.islice(fin, limit)
      files['fc'] = {'text': "".join(handle)}
      files['fc'].update(**addl_props)
      files['fc']['size'] = info.st_size

  return files


class RefPolicy(restful.ResourceDomain):
    TABLE = 'refpolicy'

    __bulk_fields__ = {
        'documents.dsl.text': (str, str),
        'parsed': (api.db.json.dumps, api.db.json.loads)
        }

    @classmethod
    def do_update(cls, params, response):

      newobject = cls.Read(params['_id'])
      dsl_hash = hashlib.md5(params['dsl']).hexdigest()

      if dsl_hash != newobject['documents']['dsl']['digest']:
          newobject['documents']['dsl']['text'] = params['dsl']
          newobject.Insert()

      response['payload'] = newobject
      return response

    @classmethod
    def do_get(cls, refpol_id, response):
        """ Returns a policy, without the document (list of allow rules)
        and the parsed version of the policy.
        """

        refpol_id = api.db.idtype(refpol_id)
        logger.info("Retrieving reference policy {0}".format(refpol_id))

        # Don't send the parsed data or the unparsed document
        refpol = RefPolicy.Find({'_id': refpol_id}, {'parsed': False, 'documents': False}, 1)[0]

        # lobster_import = { 'refpolicy': refpol.id, 'modules': [] }

        # dsl = ws_domains.call(
        #     'lobster',
        #     'translate_selinux',
        #     lobster_import
        # )

        # print("=====LOBSTER KEYS======")

        # pprint.pprint(dsl.keys())
        # pprint.pprint(dsl['result'])
        

        # if refpol.documents is None or 'dsl' not in refpol.documents:
        #     logger.info("Missing DSL. Making service request")
        #     dsl = ws_domains.call(
        #         'lobster',
        #         'translate_selinux',
        #         {
        #             'refpolicy': refpol.id,
        #             'modules': []
        #         }
        #     )

        #     if len(dsl['errors']) > 0:
        #       raise Exception("Failed to translate DSL: {0}"
        #                       .format("\n".join(
        #                           ("{0}".format(x) for x in dsl['errors']))))

        #     if 'documents' not in refpol:
        #       refpol['documents'] = {}

        #     refpol['documents']['dsl'] = {
        #         'text': dsl['result'],
        #         'mode': 'lobster',
        #         'digest': hashlib.md5(dsl['result']).hexdigest()
        #     }

        #     refpol.Insert()

        # elif 'digest' not in refpol.documents['dsl']:
        #     refpol.documents['dsl']['digest'] = hashlib.md5(
        #         refpol.documents['dsl']['text']).hexdigest()
        #     refpol.Insert()

        response['payload'] = refpol


        return response

    @classmethod
    def do_fetch_module_source(cls, params, response):
        refpol_id = api.db.idtype(params['refpolicy'])

        refpolicy = RefPolicy.Read(refpol_id)

        response['payload'] = read_module_files(
            refpolicy.modules[params['module']],
            editable=False,
            limit=1500)

        return response

    @classmethod
    def do_upload_chunk(cls, params, response):
        # Make sure the directory exists
        try:
            os.makedirs(os.path.join(
                api.config.get('storage', 'bulk_storage_dir'),
                'tmp'))
        except:
            pass

        name = params['name'][:-4] if params['name'].endswith('.zip') else params['name']

        name = os.path.basename(name)  # be a little safer
        if not name:
          raise Exception("Invalid name for policy.")

        metadata = cls.Read({'id': name})

        if metadata is None:
            metadata = cls({
                'id': name,
                'written': params['index'],
                'total': params['total'],
                'tmpfile': os.path.join(
                    api.config.get('storage', 'bulk_storage_dir'),
                    "tmp",
                    params['name']
                )
            })

        elif 'tmpfile' not in metadata and 'disk_location' in metadata:
            raise Exception('Policy already exists')
        elif metadata['written'] < params['index']:
            os.remove(metadata['tmpfile'])
            metadata.Delete()
            raise Exception("Received out-of-order chunk. "
                            "Expected {0}. Got {1}"
                            .format(metadata['written'], params['index']))

        metadata['written'] = params['index']

        mode = 'r+b' if os.path.exists(metadata['tmpfile']) else 'wb'

        with open(metadata['tmpfile'], mode) as fout:
            fout.seek(params['index'])
            raw_data = base64.b64decode(params['data'])
            fout.write(raw_data)
            fout.flush()

        metadata['written'] += params['length']
        if metadata['written'] == metadata['total']:
            try:
                metadata.extract_zipped_policy()
                module_info = metadata.read_policy_modules()
                sesearch_result = metadata.parse_policy_binary()

                errors = []

                supported_docs = {
                    'dsl': False,
                    'raw': False
                }

                # Do we have source rules?
                if len(module_info['error']) > 0:
                    errors.append(module_info['error'])
                else:
                    supported_docs['dsl'] = True

                # Do we have the binary rules?
                if len(sesearch_result['error']) > 0:
                    errors.append(sesearch_result['error'])
                else:
                    supported_docs['raw'] = True

                if not supported_docs['dsl'] and not supported_docs['raw']:
                    raise api.DisplayError("Cannot find binary policy or reference policy source in the zip file: " + '\n'.join(errors))

                if supported_docs['dsl'] is True:
                    # Import the policy into Lobster
                    lobster_import = { 'refpolicy': metadata.id, 'modules': [] }

                    lobster_json = ws_domains.call(
                        'lobster',
                        'translate_selinux',
                        lobster_import
                    )

                    # TODO check the results['error'] array to see if problems

                    metadata['documents'] = {
                        'dsl': {
                            'text': lobster_json,
                            'mode': 'dsl',
                            'digest': hashlib.md5(lobster_json).hexdigest() #hashlib.md5(api.db.json.dumps(lobster_json['result'])).hexdigest()
                        }
                    }

                metadata['supported_docs'] = supported_docs

                metadata['modules'] = module_info['data']

                if 'documents' not in metadata:
                    metadata['documents'] = {}
                metadata['documents']['raw'] = {
                    'text': sesearch_result['data'],
                    'mode': 'raw',
                    'digest': hashlib.md5(sesearch_result['data']).hexdigest()
                }
            except Exception:
                metadata.Delete()
                raise
            else:
                metadata['valid'] = True

        metadata.Insert()

        response['payload'] = {
            'progress': float(metadata['written']) / float(metadata['total']),
            'info': {
                '_id': metadata['_id'],
                'id': metadata['id']
            }
        }

        return response

    def read_policy_modules(self):
        """ Read an extracted policy off the disk, and understand what modules
        are included in it (and where they are on disk).
        """

        ret = {
            'data': {},
            'error': ''
        }

        policy_dir = os.path.join(
            api.config.get('storage', 'bulk_storage_dir'),
            'refpolicy', self['id'])

        def print_error(e):
            print(e)

        walker = os.walk(os.path.join(policy_dir, 'policy/modules'),
                         onerror=print_error)

        modules = {}

        for dirpath, dirnames, filenames in walker:
            modnames = set((fn.split('.')[0] for fn in filenames))

            for mod in modnames:
                try:
                  logger.info("Trying to open module {0}".format(mod))
                  te_file = open(os.path.join(dirpath, mod + ".te"))
                  modname, version = extract_module_version(te_file)
                except IOError as e:
                  # This indicates that the .te file doesn't exist, which
                  # really means its like "Changelog" or something, so ignore it.
                  logger.warn("Failed to open type enforcement file for {0}: {1}"
                              .format(mod, e))
                  continue
                except Exception:
                  raise

                if modname in modules:
                    raise Exception(
                        "Reference policy contains duplicate "
                        "module: '{0}'".format(modname)
                    )

                modules[modname] = {
                    'name': modname,
                    'version': version,
                    'policy_id': None,
                    'te_file':
                    os.path.join(dirpath, mod + ".te"),
                    'fc_file':
                    os.path.join(
                        dirpath,
                        mod + ".fc") if mod + ".fc" in filenames else None,
                    'if_file':
                    os.path.join(
                        dirpath,
                        mod + ".if") if mod + ".if" in filenames else None
                }

        ret['data'] = modules

        if len(modules.keys()) == 0:
            ret['error'] = 'Could not find reference policy source'

        return ret
    
    def parse_policy_binary(self):
        """ Parse a binary policy file using sesearch from setools v4.

        Find the binary policy file (must be named sepolicy). Read the allow
        rules using sesearch, and store in the database.
        The result is an empty string if the binary policy is not found, or if
        sesearch could not be run.
        """
        
        policy_dir = os.path.join(
            api.config.get('storage', 'bulk_storage_dir'),
            'refpolicy', self['id'],'policy')

        # regex for compatible policy versions
        policy_binary_regex = "^sepolicy$"
        regex_compiled = re.compile(policy_binary_regex)

        
        # count number of regex matches
        matches = 0
        re_result = None
        for fname in os.listdir(policy_dir):
            re_match_result=re.match(policy_binary_regex,str(fname))
            if re_match_result:
                re_result = re_match_result
                matches += 1

        ret = {
            'data': '',
            'error': ''
            }

        if matches < 1:
            ret['error'] = "Could not find policy binary file named sepolicy in policy directory"
            return ret
        
        # perform sesearch if we have unique policy regex match
        
        policy_file = os.path.join(policy_dir,re_result.string)
        policy_file = os.path.abspath(policy_file)
        
        try:
            # sesearch 4 prints its version info to stderr
            sesearch_version = subprocess.check_output(["sesearch","--version"], stderr=subprocess.STDOUT)

            # Only support sesearch version 4 or higher
            if sesearch_version.find('4.') >= 0:
                ret['data'] = subprocess.check_output(["sesearch","--allow",policy_file])
            else:
                ret['error'] = "Sesearch must be version 4"
        except CalledProcessError as e:
            # sesearch not installed, or cannot run
            ret['error'] = "Could not run sesearch: not installed or not on path"
        
        return ret

    def extract_zipped_policy(self):
        """ Validate that the uploaded file is actually a policy.

        Unpack it, identify that it is actually a reference policy,
        and determine what modules it contains.
        """
        import zipfile

        name = self['id']
        zipped_policy = self['tmpfile']
        policy_dir = os.path.abspath(os.path.join(
            api.config.get('storage', 'bulk_storage_dir'),
            'refpolicy'))

        if not zipfile.is_zipfile(zipped_policy):
            raise api.DisplayError("Unable to extract: file was not a ZIP archive")

        try:
            zf = zipfile.ZipFile(zipped_policy)
        except zipfile.BadZipfile:
            raise api.DisplayError("Unable to extract: file corrupted")

        # Source or binaries must be under the /<name>/policy/ directory.
        # If directory structure is incorrect, then abort.
        try:
            zf.getinfo('{0}/policy/'.format(name))
        except KeyError:
            raise api.DisplayError("File does not appear to contain "
                            "SELinux reference policy source or binary. "
                            "If your policy is named mypolicy, make sure the "
                            "zip name is mypolicy and that it contains a "
                            "directory named mypolicy. The mypolicy directory "
                            "should contain either the reference policy "
                            "source or the policy binary, or both. The policy "
                            "binary should be named sepolicy and it should be "
                            "in the mypolicy/policy directory.")

        # Delete the existing file first.
        import shutil
        try:
          shutil.rmtree(os.path.join(policy_dir, name))
        except OSError as e:
          if e.errno == 2:
            pass
          else:
            raise

        zf.extractall(policy_dir)

        self['disk_location'] = policy_dir
        os.remove(zipped_policy)
        del self['tmpfile']
        self['id'] = name


def __instantiate__():
    return RefPolicy
