
import tornado.web

class Base(tornado.web.RequestHandler):
    def get_current_user(self):
        _id  = self.get_secure_cookie('id')
        if _id is None:
            self.clear_cookie('id')
        return _id

class Index(Base):
    def get(self):
        self.render('index.html')
