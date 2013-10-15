
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
        self.render('index.html')

from .auth import *
