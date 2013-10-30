
import socket
import logging

import tornado.websocket

class WebSocket(tornado.websocket.WebSocketHandler):
    def open(self, channel):
        self.stream.socket.setsockopt(socket.SOL_TCP, socket.TCP_NODELAY, 1)
        self.application.sockets[self] = self

    def on_message(self, msg):
        for ws in self.application.sockets:
            if ws is self:
                continue
            ws.write_message(msg)

    def on_close(self):
        del self.application.sockets[self]
