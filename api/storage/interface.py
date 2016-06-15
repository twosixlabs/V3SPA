
import json
import collections
import logging

import api

__all__ = ['initialize', 'Entry']


def merge(d, u):
    for k, v in u.iteritems():
        if isinstance(v, collections.Mapping):
            r = merge(d.get(k, {}), v)
            d[k] = r
        else:
            d[k] = u[k]
    return d


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


def get_field(collection, field_desc):
  current = collection
  for field in field_desc.split('.'):
    current = current.get(field)
    if current is None:
      return None

  return current


def set_field(collection, field_desc, value):
  current = collection
  fields = field_desc.split('.')
  for field in fields[:-1]:
    n = current.get(field)
    if n is None:
      current[field] = {}
    current = n

  current[fields[-1]] = value


class Entry(collections.MutableMapping):
    __bulk_fields__ = {}

    def __init__(self, entry):
        self.id = entry['id']
        self.entry = dict(entry.items())

        for field_desc, (enc, dec) in self.__bulk_fields__.iteritems():
          bulk_field = get_field(self.entry, field_desc)
          if bulk_field is None:
            pass
          else:
            blobid = bulk_field
            set_field(self.entry, field_desc,
                dec(api.db.RetrieveBlobData(blobid)))

        self.Init()

    def Init(self):
        pass

    def __len__(self):
      return len(self.entry)

    def __iter__(self):
      return self.entry.__iter__()

    @classmethod
    def Find(cls, criteria, selection=None, max=0):
        result = api.db.Find(cls.TABLE, criteria, selection, limit=max)
        if result is None:
          return []
        return map(cls, result)

    @classmethod
    def Create(cls, values):
        return cls(values).Insert()

    def Insert(self):
        # remove any actual bulk data and store it in the blob store
        stored_blobs = {}
        current_data = api.db.FindOne(self.TABLE, self._id)

        for field_desc, (enc, dec) in self.__bulk_fields__.iteritems():
          bulk_field = get_field(self.entry, field_desc)
          if bulk_field is None:
            pass
          else:
            current_db_blob = get_field(current_data, field_desc)
            api.db.RemoveBlob(current_db_blob)

            blob = bulk_field
            blobid = api.db.InsertBlob(enc(blob))
            stored_blobs[field_desc] = blob
            set_field(self.entry, field_desc, blobid)

        # Remove and replace the blobs with blobids
        # so that we can insert them in the database. 
        # Then put them back.
        api.db.Insert(self.TABLE, self.entry)

        for field_desc, blob in stored_blobs.iteritems():
          set_field(self.entry, field_desc, blob)

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

    def Update(self, values={}):
        if values:
            merge(self.entry, values)
        # WE use Insert here because it replaces, 
        # and we're not doing anything so complicated as needed 
        # by  MongoDB's update
        api.db.Insert(self.TABLE, self.entry)
        return self

    def Delete(self):
        data = api.db.FindOne(self.TABLE, self.entry['_id'])

        for field_desc, (enc, dec) in self.__bulk_fields__.iteritems():
          bulk_field = get_field(data, field_desc)
          logging.info("Removing {0}".format(field_desc))
          api.db.RemoveBlob(bulk_field)

        try:
          api.db.Remove(self.TABLE, self['_id'])
        except KeyError:  # It wasn't in the database anyway
          pass
        return True

    @property
    def json(self):
        return api.db.json.dumps(dict(self.entry), indent=2)

    def __getattr__(self, attr):
      try:
        val = self.entry.get(attr)
        return val
      except AttributeError:
        return object.__getattribute__(self, attr)

    def __getitem__(self, key):
        return self.entry.__getitem__(key)

    def __setitem__(self, key, value):
        return self.entry.__setitem__(key, value)

    def __delitem__(self, key):
        return self.entry.__delitem__(key)

    def keys(self):
        return self.entry.keys()
