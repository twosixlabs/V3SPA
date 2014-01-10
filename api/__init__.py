
import os

root = os.path.dirname(__file__)
root = os.path.join(root, '..')
root = os.path.abspath(root)

class error(Exception):
    def __init__(self, fmt, *args):
        self.str = fmt % args

    def __str__(self):
        return self.str

import settings
import storage
