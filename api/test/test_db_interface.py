import nose.tools
import mock
from hamcrest import equal_to, assert_that, is_, none, has_entry
import unittest

import api.storage.interface
from api.handlers.ws_domains.policies import Policy
import api.settings

class TestMongoInterface(unittest.TestCase):

  @classmethod
  def setup_class(self):
    api.config.add_section('storage')
    api.config.set('storage', 'engine', 'mongo')
    api.config.set('storage', 'uri',
        'mongodb://localhost')
    api.config.set('storage', 'db_name',
        'vespa-test')
    api.storage.interface.initialize()

  def tearDownAll(self):
    api.db.db.dropDatabase()

  def setUp(self):
    self.example_id = api.db.json.ObjectId()
    api.db.db['policies'].insert([
      {"_id": self.example_id, "id": "Example1"},
      {"_id": api.db.json.ObjectId(), "id": "Example2"},
      {"_id": api.db.json.ObjectId(), "id": "Example3"},
    ])

  def test_read(self):
    entry = Policy.Read(self.example_id)
    assert_that(entry, has_entry('id', 'Example1'), 'read by id')

    entry = Policy.Read({'id': 'Example3'})
    assert_that(entry, has_entry('id', 'Example3'), 'read by params')

    entry = Policy.Read({'id': 'Example4'})
    assert_that(entry, is_(none()), 'read invaldi')
