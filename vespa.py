#!/usr/bin/python

import sys
import os
import logging
logging.getLogger().setLevel(logging.DEBUG)

import api
api.settings.parse()
api.storage.initialize()

import api.handlers

import tornado.web
import tornado.ioloop


api.ioloop = tornado.ioloop.IOLoop.instance()


def main():

    addr = api.args.addr or api.config.get('server', 'address')
    port = api.args.port or api.config.getint('server', 'port')

    try:
        with open(os.path.join(api.root, 'etc', 'cookie.secret')) as fp:
            cookie_secret = fp.read(44)
    except IOError:
        logging.critical('Could not read cookie.secret')
        return -1

    websocket_handler = api.handlers.WSRouter(api.handlers.WebSocket, '/ws')

    patterns = [
        (r'/',             api.handlers.Index     ),
        (r'/login',        api.handlers.Login     ),
        (r'/logout',       api.handlers.Logout    ),
        (r'/download/(.*)',     api.handlers.Download  )
        ] +  websocket_handler.urls

    settings = dict(
        static_path   = os.path.join(api.root, 'static'),
        template_path = os.path.join(api.root, 'server_templates'),
        cookie_secret = cookie_secret,
        login_url     = '/login',
        debug         = api.config.get('main', 'debug')
        )

    api.app = tornado.web.Application(patterns, **settings)
    websocket_handler.set_application(api.app)
    api.app.sockets = {}

    try:
        api.app.listen(port, addr)
    except Exception as e:
        raise api.error('Could not listen on address: %s', e)

    logging.info('Listening on %s:%d', addr, port)

    try:
        api.ioloop.start()
    except KeyboardInterrupt:
        api.ioloop.stop()

    return 0

if '__main__' == __name__:
    try:
        sys.exit(main())
    except api.error as e:
        logging.critical('%s', e)
        sys.exit(-1)
