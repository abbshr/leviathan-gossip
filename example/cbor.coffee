cbor = require 'cbor'
net = require 'net'

server = net.createServer (socket) ->
  ds = new cbor.Decoder
  es = new cbor.Encoder
  
  es.pipe socket
  .pipe ds
  .on 'data', (obj) ->
    console.log obj
    es.end obj
  .on 'end', ->
    console.log 'session end'
    # es.end()
    
server.listen 3000