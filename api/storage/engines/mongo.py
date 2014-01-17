import api
import motor
from tornado import gen

class Database(object):

  def __init__(self):
    try:
      path = api.config.get('storage', 'path')
      self._client = motor.MotorClient().open_sync()
    except:
      self._client = motor.MotorClient().open_sync()

    self.db = self._client.vespa_dev

  @gen.engine
  def Find(self,collection, params):
    cursor = self.db[collection].find(params)
    yield motor.Op(cursor.to_list, length=100)

  @gen.engine
  def FindOne(self, collection, params):
    yield motor.Op(self.db[collection].find_one(params))

  @gen.engine
  def Insert(self, collection, entry):
    yield motor.Op(self.db[collection].save(entry))

  @gen.engine
  def Update(self, collection, entry):
    yield motor.Op(self.db[collection].update(entry))

  @gen.engine
  def Remove(self, collection, id):
    yield motor.Op(self.db[collection].remove({'_id': id}))


#def Database():

  #if _db is None:
    #_db = MongoWrapper()

  #return _db
