import api
import pymongo
import bson.json_util
from tornado import gen
import logging
logger = logging.getLogger(__name__)

class Database(object):

  json = bson.json_util

  def __init__(self):
    try:
      path = api.config.get('storage', 'path')
      self._client = pymongo.MongoClient()
    except:
      self._client = pymongo.MongoClient()

    self.db = self._client.vespa_dev

  def Find(self, collection, criteria, projection, populate=None):
    cursor = self.db[collection].find(criteria, projection)
    results = list(cursor.limit(100))
    return results

  def FindOne(self, collection, params):
    return self.db[collection].find_one(params)

  def Insert(self, collection, entry):
    return self.db[collection].save(entry)

  def Update(self, collection, entry):
    return self.db[collection].update(entry)

  def Remove(self, collection, id):
    return self.db[collection].remove({'_id': id})
