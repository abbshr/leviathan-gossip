{EventEmitter} = require 'events'
dgram = require 'dgram'
net = require 'net'
msgpack = require 'msgpack'

class Gossip extends EventEmitter

  constructor: (args = {}) ->
    {@addr, @port, @secval, @alive, @seeds} = args
    @local = "#{@addr}:#{@port}"
    @peer = net.createServer @_initSocket
    @_init()
    super()

  _initSocket: (socket) ->
    socket
    .on 'error', onError
    .on 'close', onClose
    .on 'timeout', onTimeout
    .on 'end', onEnd
    ms = new msgpack.Stream socket
    ms.on 'msg', onMsg

  _init: ->
    # node discover
    @join @seeds, info,

  onPolling: ->
    clearTimeout @_pollref
    @_ref = setTimeout =>
      spread()
    , @secval * 1000

  run: ->
    stateInfo = Buffer JSON.stringify type: 'joining', data: local
    @node.bind @port, =>
      @join @seeds, stateInfo unless local in @seeds
      spread()

  # polling: =>
  #   @_ref = setTimeout =>
  #     spread @polling
  #   , @secval * 1000

  randomNode: (type) ->
    rand = Math.random()
    switch type
      when 'seed' then @seeds[rand * @seeds.length >> 0]
      when 'alive' then @alive[rand * @alive.length >> 0]
      when 'unreachable' then @unreachable[rand * @unreachable.length >> 0]

  spread: ->
    if @alive.length > 0
      liveNode = @randomNode 'alive'
      @sync liveNode
    if @unreachable.length > 0
      unreachedNode = @randomNode 'unreachable'
      @sync unreachedNode

    if liveNode not in @seeds or @alive.length < @seeds.length
      seedNode = @randomNode 'seed'
      @sync seedNode

    @once 'polling', @onPolling
    @_pollref = setTimeout =>
      @removeListener 'polling', @onPolling if @listenerCounts 'polling' > 0
      @spread()
    , 20 * 1000

  # push/pull model
  polling: (peers, dataset) =>
    # choose an alive peer
    # choose an unreachable peer
    # (choose a seed)
    # create the connection
    packet = []
    [ip, port] = peer.split ':'
    node = net.connect port, ip
    ms = new msgpack.Stream node
    ms.on 'msg', (msg) =>
      # diff dataset
      # parse the chunk
      # yield the packet
      # pull delta
      @emit 'peers_update', @onPeersUpdate
      @emit 'data_update', @onDataUpdate
      # push delta
      delta = msgpack.pack @peers, @ownedData
      node.write delta
    node.on 'connect', =>
        # push digest
        # dataset = Buffer @peers, @ownedData
        dataset = msgpack.pack @peers, @ownedData
        node.write dataset
      .on 'error', @onError
      .on 'timeout', @onTimeout

module.exports = Gossip
