import api
import pymongo
import bson.json_util
from tornado import gen
import logging
logger = logging.getLogger(__name__)

import gridfs


class Database(object):

  idtype = bson.json_util.ObjectId
  json = bson.json_util

  def __init__(self):
    try:
      path = api.config.get('storage', 'uri')
      self._client = pymongo.MongoClient(path)
    except:
      self._client = pymongo.MongoClient()

    db_name = api.config.get('storage', 'db_name')
    self.db = self._client[db_name]

    self.bulk = gridfs.GridFS(self.db, 'bulkfiles')

  def RetrieveBlob(self, identifier):
      return self.bulk.get(identifier)

  def RetrieveBlobData(self, identifier):
      return self.bulk.get(identifier).read()

  def InsertBlob(self, blob):
      return self.bulk.put(str(blob))

  def RemoveBlob(self, identifier):
      self.bulk.delete(identifier)
      return True

  def Find(self, collection, criteria, projection, **opts):
    if '_id' in criteria:
      criteria['_id'] = Database.json.ObjectId(criteria['_id'])

    cursor = self.db[collection].find(criteria, projection)
    results = list(cursor.limit(100))
    return results

  def FindOne(self, collection, id):
    return self.db[collection].find_one(Database.json.ObjectId(id))

  def Insert(self, collection, entry):
    if '_id' in entry:
      entry['_id'] = Database.json.ObjectId(entry['_id'])
    return self.db[collection].save(entry)

  def Update(self, collection, entry):
    entry['_id'] = Database.json.ObjectId(entry['_id'])
    return self.db[collection].update(entry)

  def Remove(self, collection, id):
    return self.db[collection].remove({'_id': Database.json.ObjectId(id)})
