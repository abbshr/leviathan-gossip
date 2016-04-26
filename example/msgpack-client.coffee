msgpack = require 'msgpack-lite'
net = require 'net'

client = net.connect port: 3000
.on 'connect', ->
  console.log 'connect'
  decodeStream = msgpack.createDecodeStream()
  encodeStream = msgpack.createEncodeStream()
  encodeStream.pipe client
  .pipe decodeStream
  .on 'data', (msg) ->
    console.log msg
  
  encodeStream.write bar: "foo"
  encodeStream.write fff: 'ggg'
  encodeStream.end()