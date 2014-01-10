#!/usr/bin/python

import sys
import os
import logging

import api
import api.handlers

import tornado.web
import tornado.ioloop

api.ioloop = tornado.ioloop.IOLoop.instance()

def main():
    api.settings.parse()
    api.storage.initialize()

    addr = api.args.addr or api.config.get('server', 'address')
    port = api.args.port or api.config.getint('server', 'port')

    try:
        with open(os.path.join(api.root, 'etc', 'cookie.secret')) as fp:
            cookie_secret = fp.read(44)
    except IOError:
        logging.critical('Could not read cookie.secret')
        return -1

    patterns = [
        (r'/',             api.handlers.Index     ),
        (r'/login',        api.handlers.Login     ),
        (r'/logout',       api.handlers.Logout    ),
        ] +  api.handlers.WebSocketRouter.urls

    settings = dict(
        static_path   = os.path.join(api.root, 'static'),
        template_path = os.path.join(api.root, 'templates'),
        cookie_secret = cookie_secret,
        login_url     = '/login',
        debug         = True
        )

    api.app = tornado.web.Application(patterns, **settings)
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
