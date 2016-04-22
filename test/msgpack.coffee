msgpack = require 'msgpack-lite'
net = require 'net'

server = net.createServer (socket) ->
  decodeStream = msgpack.createDecodeStream()
  encodeStream = msgpack.createEncodeStream()
  encodeStream
  .pipe socket
  socket.pipe decodeStream
  .on 'data', (msg) ->
    console.log msg
    encodeStream.write msg
    
server.listen 3000