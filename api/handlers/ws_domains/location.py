import logging
logger = logging.getLogger(__name__)

import api
import restful

class Location(restful.ResourceDomain):
    TABLE = 'object_locations'

def __instantiate__():
  return Location
