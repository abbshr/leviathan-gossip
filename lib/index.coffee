net = require 'net'
assert = require 'assert'
{EventEmitter} = require 'events'

util = require 'archangel-util'
{log} = require 'util'
cbor = require 'cbor'
msgpack = require 'msgpack-lite'
async = require 'async'

ScuttleButt = require './scuttlebutt'
Peer = require './peer'
State = require './state'

# coding note: 
#   peer_info ≌ id ≌ "#{addr}:#{port}"
class Gossip extends EventEmitter

  # parameters

  # @seeds:
  # @id:
  # @addr:
  # @port:
  # @gossip_val:
  # @heartbeat_val:
  # @health_check_val:
  # @phi_threshold:
  # @val_max_len:
  # @reduce_val:
  constructor: (args = {}) ->
    {@addr, @port, @alias, @seeds, @gossip_val, @health_check_val, @heartbeat_val, @phi_threshold, @val_max_len} = args
    assert.notEqual @seeds.length, 0
    assert.ok @gossip_val >= 1000
    assert.ok @health_check_val >= 1000
    
    @id = "#{@addr}:#{@port}"
    @suspend = []
    @active = []
    @peers = {}
    @state = new State {@id}
    @opt = {@phi_threshold, @val_max_len}
    @scuttlebutt = new ScuttleButt @state, @peers, @opt
    @__heartbeat = 0
    super()

  run: (callback = ->) ->
    @initSeeds()
    @initPeers()
    @initHandlers()
    @serve()
    @heartbeat()
    @polling()
    @monitor()
    callback()
    # @reduce()
    
  initSeeds: ->
    util.unorderList.rm @seeds, @id
    log "init seeds:", @seeds

  initPeers: ->
    new_peers = for id in @seeds
      @peers[id] = new Peer {id, @opt}
      id
    
    setImmediate =>
      @emit "peers_discover", new_peers if new_peers.length
      
    @active.push new_peers...
    
    log "found #{new_peers.length} active peers"

  serve: ->
    @server = net.createServer (socket) =>
      ds = new cbor.Decoder()
      es = new cbor.Encoder()
      # decodeStream = msgpack.createDecodeStream()
      # encodeStream = msgpack.createEncodeStream()
      
      onData = @_onData.bind this, {es}
      
      es.pipe socket
      .pipe ds
      .on 'data', onData
      
      socket.on 'error', (e) -> log e
        
    .listen @port, =>
      log "server start:", @port

  heartbeat: ->
    # log "start heartbeat", @__heartbeat, @state.data
    @state.set "__heartbeat", ++@__heartbeat
    setTimeout =>
      @heartbeat()
    , @heartbeat_val

  polling: =>
    # TODO: consider if there is need to wait the longest request
    setTimeout =>
      # log "start polling"
      @schedule @polling
    , @gossip_val

  monitor: ->
    # log "start monitor"
    setTimeout =>
      @checkHealth()
      @monitor()
    , @health_check_val

  # TODO: reduce the deleted keys
  # reduce: ->
  #   setTimeout =>
  #     @state.delh k for k in @state._trash
  #     @reduce()
  #   , @reduce_val

  checkHealth: ->
    # log "start health check"
    _suspend = []
    _recover = []
    for id, peer of @peers
      [source, target] = if peer.detect util.curr_ts()
        _recover.push id unless peer.isActive
        peer.isActive = yes
        [@suspend, @active]
      else
        _suspend.push id if peer.isActive
        peer.isActive = no
        [@active, @suspend]

      util.unorderList.rm source, id
      target.push id unless id in target
    
    setImmediate =>
      @emit 'peers_recover', _recover if _recover.length
      @emit 'peers_suspend', _suspend if _suspend.length

  schedule: (callback) ->
    # log "start schedule peers"
    queue = []
    # TODO: schedule with a probablity
    if @active.length > 0
      queue.push util.getRandomItem @active
      
    if @suspend.length > 0
      queue.push util.getRandomItem @suspend
      
    if (queue[0] not in @seeds and @seeds.length > 0) or @active.length < @seeds.length
      queue.push util.getRandomItem @seeds
    
    # log "peers to gossip with:", queue
    return callback() if queue.length is 0

    queue = for id in queue
      [addr, port] = id.split ':'
      (cb) => @gossip addr, port, cb

    # TODO: consider if there is need to wait the longest request
    async.parallel queue, (err, done) ->
      callback()

  gossip: (peer_addr, peer_port, callback) =>
    # TODO: client events handle configuration
    socket = net.connect peer_port, peer_addr
    
    socket.setTimeout 5000
      .on 'error', (e) => 
        log "connect to #{peer_addr}:#{peer_port} failure due to", e.message
        callback null
      
      .on 'timeout', =>
        log "#{peer_addr}:#{peer_port} timeout"
        socket.end()
        callback null
      
      .on 'connect', =>
        ds = new cbor.Decoder()
        es = new cbor.Encoder()
        onData = @_onData.bind this, {es, callback}
        
        es.pipe socket
        .pipe ds
        .on 'data', onData 
        
        # log "gossip with", peer_addr, peer_port
        es.write @scuttlebutt.yieldDigest()

  _onData: (opt, msg) =>
    {es, callback} = opt
    {type, digest, deltas, receipt} = msg
    
    switch type
      when 'pull_digest'
        @emit '_digest', es, digest
      when 'pull_deltas'
        @emit '_deltas', es, deltas, receipt, callback
      when 'push_deltas'
        @emit '_push_deltas', deltas
      # when 'delete'
      #   @emit '_delete', es, msg.key
      else
        log 'unknown gossip packet'

  initHandlers: ->
    @on '_digest', (es, digest) ->      
      es.write @scuttlebutt.yieldPullDeltas digest

    @on '_deltas', (es, deltas, receipt, done) ->
      # update new k-v in state
      [new_peers, updates] = @scuttlebutt.applyUpdate deltas
      @active.push new_peers...
      
      setImmediate =>
        @emit 'peers_discover', new_peers if new_peers.length
        @emit 'updates', updates if updates.length

      es.end @scuttlebutt.yieldPushDeltas receipt
      done null

    @on '_push_deltas', (deltas) ->
      # update new k-v in state
      [new_peers, updates] = @scuttlebutt.applyUpdate deltas
      @active.push new_peers...
      
      setImmediate =>
        @emit 'peers_discover', new_peers if new_peers.length
        @emit 'updates', updates if updates.length

    # TODO: spread delete command
    # @on '_delete', (ms, key) ->
    #   @state.dels key

  set: (k, v) ->
    @state.set k, v
    
  get: (r, k) ->
    state = if r is @state.id
      @state
    else
      @peers[r]?.state
    state?.getv k
    
  getn: (r, k) ->
    state = if r is @state.id
      @state
    else
      @peers[r]?.state
    state?.getn k
    
  # TODO: spread delete command
  # del: (k) ->
  #   @state.dels k

module.exports = Gossip
