
import json
import UserDict
import logging

import api

__all__ = ['initialize', 'Entry']


def initialize():
    engine = api.config.get('storage', 'engine')

    path = 'api.storage.engines.' + engine

    try:
        mod = __import__(path)
    except ImportError as e:
        raise api.error('Unknown storage engine: %s [%s]', engine, e)

    for sub in path.split('.')[1:]:
        mod = getattr(mod, sub)

    try:
        db = getattr(mod, 'Database')
    except AttributeError:
        raise api.error('Bad storage engine: %s', engine)

    api.db = db()
    logging.info('Storage engine: %s', engine)


class Entry(UserDict.DictMixin):
    def __init__(self, entry):
        self.id = entry['id']
        self.entry = dict(entry)
        self.Init()

    def Init(self):
        pass

    @classmethod
    def Find(cls, criteria, selection=None):
        result = api.db.Find(cls.TABLE, criteria, selection)
        if result is None:
          return []
        return map(cls, result)

    @classmethod
    def Create(cls, values):
        return cls(values).Insert()

    def Insert(self):
        api.db.Insert(self.TABLE, self.entry)
        return self

    @classmethod
    def Read(cls, params):
        if isinstance(params, dict):
          try:
            entry = api.db.Find(cls.TABLE, params, None, limit=1)[0]
          except IndexError:
            entry = None
        else:
          entry = api.db.FindOne(cls.TABLE, params)
        return cls(entry) if entry else None

    def Update(self, values=None):
        if values:
            self.entry.update(values)
        # WE use Insert here because it replaces, 
        # and we're not doing anything so complicated as needed 
        # by  MongoDB's update
        api.db.Insert(self.TABLE, self.entry)
        return self

    def Delete(self):
        try:
          api.db.Remove(self.TABLE, self['_id'])
        except KeyError:  # It wasn't in the database anyway
          pass
        return True

    @property
    def json(self):
        return api.db.json.dumps(dict(self.entry), indent=2)

    def __getattr__(self, attr):
      if attr in self.entry:
        return self.entry.__getitem__(attr)
      return object.__getattribute__(self, attr)

    def __getitem__(self, key):
        return self.entry.__getitem__(key)

    def __setitem__(self, key, value):
        return self.entry.__setitem__(key, value)

    def __delitem__(self, key):
        return self.entry.__delitem__(key)

    def keys(self):
        return self.entry.keys()
