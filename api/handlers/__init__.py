
import bson.errors
import tornado.web

class Base(tornado.web.RequestHandler):
    def get_current_user(self):
        uid  = self.get_secure_cookie('uid')
        if uid is None:
            self.clear_cookie('uid')
        return uid

class Index(Base):
    @tornado.web.authenticated
    def get(self):
        self.redirect('/static/index.html')

class Download(Base):
    @tornado.web.authenticated
    def get(self, filetype):
      import api.handlers.ws_domains.refpolicy as refpolicy
      import api.handlers.ws_domains as ws_domains
      self.set_header('Cache-control', 'no-cache')

      identifier = self.get_argument('id', None)

      if filetype == 'refpolicy':
        if identifier is None:
          self.clear()
          self.set_status(400)
          self.finish("Missing required parameter: id")
          return

        # Check the identifier.
        try:
          identifier = api.db.idtype(identifier)
        except bson.errors.InvalidId:
          self.clear()
          self.set_status(404)
          self.finish("Could not find policy: {0}".format(identifier))

        refpolicy = refpolicy.RefPolicy.Read(identifier)
        if not refpolicy:
          self.clear()
          self.set_status(404)
          self.finish("Could not find policy: {0}".format(identifier))
          return

        selinux = ws_domains.call(
            'lobster',
            'export_selinux',
            refpolicy.documents['dsl']['text']
        )

        self.set_header(
            'Content-Type', 'text/plain')

        self.set_header(
            'Content-Length', len(selinux))

        self.set_header(
            'Content-Disposition',
            'attachment;filename={fname};size={length}'
            .format(fname=refpolicy.id, length=len(selinux)))

        self.finish(selinux)
      else:
        self.clear()
        self.set_status(400)
        self.finish("Unrecognized filetype: {0}".format(filetype))

from .auth  import *
from .ws    import *
