cbor = require 'cbor'
net = require 'net'

client = net.connect port: 3000
.on 'connect', ->
  console.log 'connect'
  ds = new cbor.Decoder
  es = new cbor.Encoder
  es.pipe client
  .pipe ds
  .on 'data', (obj) ->
    console.log obj
  
  # es.write bar: "foo"
  # es.write fff: 'ggg'
  es.write bar: 'foo'