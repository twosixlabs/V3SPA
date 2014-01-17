
import json
import UserDict
import logging

import api

__all__ = ['initialize', 'Entries', 'Entry']

def initialize():
    engine = api.config.get('storage', 'engine')

    path = 'api.storage.engines.' + engine

    try:
        mod = __import__(path)
    except ImportError:
        raise api.error('Unknown storage engine: %s', engine)

    for sub in path.split('.')[1:]:
        mod = getattr(mod, sub)

    try:
        db = getattr(mod, 'Database')
    except AttributeError:
        raise api.error('Bad storage engine: %s', engine)

    api.db = db()
    logging.info('Storage engine: %s', engine)


class Entries:
    def __init__(self, entries):
        self.entries = entries

    @classmethod
    def Read(cls, params=None, sort=None):
        return cls(api.db.Find(cls.ENTRY.TABLE, params, sort))

    def Delete(self):
        for entry in self.entries:
            self.ENTRY(entry).Delete()
        pass

    @classmethod
    def Count(cls):
        return api.db.Count(cls.ENTRY.TABLE)

    def __len__(self):
        return len(self.entries)

    def __iter__(self):
        for entry in self.entries:
            yield self.ENTRY(entry)

    def __getitem__(self, idx):
        return self.entries.__getitem__(idx)

    @property
    def json(self):
        return json.dumps(self.entries, indent=2)


class Entry(UserDict.DictMixin):
    def __init__(self, entry):
        self.id     = entry['id']
        self.entry = dict(entry)
        self.Init()

    def Init(self):
        pass

    @classmethod
    def Find(cls, params, sort):
        result = api.db.Find(cls.TABLE, params)
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
    def Read(cls, _id):
        entry = api.db.FindOne(cls.TABLE, _id)
        return cls(entry) if entry else None

    def Update(self, values=None):
        if values:
            self.entry.update(values)
        api.db.Update(self.TABLE, self.entry)
        return self

    def Delete(self):
        api.db.Remove(self.TABLE, self.id)
        return True

    @property
    def json(self):
        return json.dumps(dict(self.entry), indent=2)

    def __getitem__(self, key):
        return self.entry.__getitem__(key)

    def __setitem__(self, key, value):
        return self.entry.__setitem__(key, value)

    def __delitem__(self, key):
        return self.entry.__delitem__(key)

    def keys(self):
        return self.entry.keys()
