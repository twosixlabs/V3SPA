
import tornado.web

class Login(tornado.web.RequestHandler):
    def get(self):
        self.render('login.html')

    def post(self):
        username = self.get_argument('username', 'admin')
        self.set_secure_cookie('uid', username)
        self.redirect(self.get_argument('next', '/'))

class Logout(tornado.web.RequestHandler):
    def get(self):
        self.clear_cookie('uid')
        self.redirect(self.get_argument('next', '/'))
