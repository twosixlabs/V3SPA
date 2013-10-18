
import random

import api

try:
    import sqlite3
except ImportError:
    raise api.error('Missing sqlite3 module\n')

# Utility function to create a unique id
def uid(bits=31):
    return random.randrange(2**bits)

class Database:
    def __init__(self, path):
        self.conn = sqlite3.connect(path)
        self.conn.row_factory = sqlite3.Row
        self.cursor = self.conn.cursor()

    def Find(self, table, params=None, sort=None):
        statement = 'SELECT * FROM ' + table;
        if params:
            statement += ' WHERE ' + params
        if sort:
            statement += ''

        self.cursor.execute(statement)
        return self.cursor.fetchall()

    def FindOne(self, table, _id):
        statement = 'SELECT * FROM {0} WHERE id = ?'.format(table)
        self.cursor.execute(statement, [_id])
        return self.cursor.fetchone()

    def Count(self, table):
        statement = 'SELECT count(*) FROM {0}'.format(table)
        self.cursor.execute(statement)
        return self.cursor.fetchone()[0]

    def Insert(self, table, values):
        columns = ','.join(values.keys())
        placeholder = ','.join('?' * len(values))
        statement = 'INSERT INTO {0} ({1}) VALUES ({2})'.format(table, columns, placeholder)

        try:
            self.cursor.execute(statement, values.values())
        except sqlite3.ProgrammingError:
            raise

        self.conn.commit()

    def Update(self, table, values):
        _id = values['id']
        columns = ','.join(s + '=?' for s in values.keys())
        statement = 'UPDATE {0} SET {1} WHERE id=?'.format(table, columns, _id)
        try:
            self.cursor.execute(statement, values.values() + [_id])
        except sqlite3.ProgrammingError:
            raise

        self.conn.commit()

    def Remove(self, table, _id):
        statement = 'DELETE FROM {0} WHERE id = ?'.format(table)
        self.cursor.execute(statement, [_id])
        self.conn.commit()
