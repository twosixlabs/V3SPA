import logging
logger = logging.getLogger(__name__)

import base64
import os
import re

import restful
import api


class RefPolicy(restful.ResourceDomain):
    TABLE = 'refpolicy'

    @classmethod
    def do_upload_chunk(cls, params, response):
        # Make sure the directory exists
        try:
            os.makedirs(os.path.join(
                api.config.get('storage', 'bulk_storage_dir'),
                'tmp'))
        except:
            pass

        metadata = cls.Read({'id': params['name']})
        print params['index']
        print metadata

        if metadata is None:
            metadata = cls({
                'id': params['name'],
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
                metadata['modules'] = metadata.read_policy_modules()
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
        policy_dir = os.path.join(
            api.config.get('storage', 'bulk_storage_dir'),
            'refpolicy', self['id'])

        def print_error(e):
            print(e)

        walker = os.walk(os.path.join(policy_dir, 'policy/modules'),
                         onerror=print_error)

        modules = {}
        mod_defn_re = re.compile(
            r'policy_module\((?P<name>[a-zA-Z]+),\s*(?P<version>[0-9]+\.[0-9]+\.[0-9]+)\)')

        for dirpath, dirnames, filenames in walker:
            modnames = set((fn.split('.')[0] for fn in filenames))

            for mod in modnames:
                with open(os.path.join(dirpath, mod + ".te")) as te_file:
                    for line in te_file:
                        match = mod_defn_re.match(line)
                        if match:
                            if match.group( 'name' ) in modules:
                                raise Exception(
                                    "Reference policy contains duplicate "
                                    "module: '{0}'".format(match.group('name'))
                                )
                            modules[match.group('name')] = {
                                'name': match.group('name'),
                                'version': match.group('version'),
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

        return modules

    def extract_zipped_policy(self):
        """ Validate that the uploaded file is actually a policy.

        Unpack it, identify that it is actually a reference policy,
        and determine what modules it contains.
        """
        import zipfile

        import pdb; pdb.set_trace()
        name = self['id'][:-4] if self['id'].endswith('.zip') else self['id']
        zipped_policy = self['tmpfile']
        policy_dir = os.path.join(
            api.config.get('storage', 'bulk_storage_dir'),
            'refpolicy')

        if not zipfile.is_zipfile(zipped_policy):
            raise Exception("Unable to extract: file was not a ZIP archive")

        try:
            zf = zipfile.ZipFile(zipped_policy)
        except zipfile.BadZipfile:
            raise Exception("Unable to extract: file corrupted")

        try:
            zf.getinfo('{0}/policy/modules.conf'.format(name))
            zf.getinfo('{0}/policy/modules/'.format(name))
        except KeyError:
            raise Exception("File does not appear to contain "
                            "SELinux reference policy source")

        zf.extractall(policy_dir)

        self['disk_location'] = policy_dir
        os.remove(zipped_policy)
        del self['tmpfile']
        self['id'] = name


def __instantiate__():
    return RefPolicy
