import logging
logger = logging.getLogger(__name__)

import base64
import os

import restful
import api

try:
    os.makedirs(api.config.get('storage', 'bulk_storage_dir'))
except:
    pass


class RefPolicy(restful.ResourceDomain):
    TABLE = 'refpolicy'

    @classmethod
    def do_upload_chunk(cls, params, response):
        metadata = cls.Read({'id': params['name']})

        if metadata is None:
            metadata = cls({
                'id': params['name'],
                'written': params['index'],
                'total': params['total'],
                'ondisk': os.path.join(
                    api.config.get('storage', 'bulk_storage_dir'),
                    params['name']
                )
            })

        elif metadata['written'] == metadata['total']:
            raise Exception('File already exists')
        else:
            metadata['written'] = params['index']

        with open(metadata['ondisk'], 'wb') as fout:
            fout.seek(params['index'])
            raw_data = base64.b64decode(params['data'])
            fout.write(raw_data)
            fout.flush()

        metadata['written'] += params['length']
        if metadata['written'] == metadata['written']:
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


def __instantiate__():
    return RefPolicy
