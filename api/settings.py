
import os
import argparse
import collections
import ConfigParser
import logging

import api

argparser = argparse.ArgumentParser()
argparser.add_argument('--ini')
argparser.add_argument('--addr')
argparser.add_argument('--port', type=int)

def parse():
    api.args = argparser.parse_args()

    api.config = ConfigParser.SafeConfigParser(dict_type=collections.OrderedDict)
    api.config.optionxform = str

    ini_files = [
        os.path.join(api.root, 'etc', 'vespa.ini'),
        os.path.join(api.root, 'etc', 'vespa.ini.local')
        ]

    if api.args.ini:
        ini_files.append(api.args.ini)

    try:
        ok = api.config.read(ini_files)
    except ConfigParser.ParsingError as e:
        raise api.error('Unable to parse file: %s', e)

    if not ok:
        raise api.error('Unable to read config file')

    logging.basicConfig(
        format  = '%(asctime)s %(levelname)-8s %(message)s',
        datefmt = '%Y-%m-%d %H:%M:%S',
        level   = logging.INFO
        )
