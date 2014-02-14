import logging
logger = logging.getLogger(__name__)

import api
import restful

class Policy(restful.ResourceDomain):
    TABLE = 'policies'

