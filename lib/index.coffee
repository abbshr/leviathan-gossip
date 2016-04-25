net = require 'net'
assert = require 'assert'
{EventEmitter} = require 'events'

util = require 'archangel-util'
{log} = require 'util'
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
  # @reduce_val:
  constructor: ({@addr, @port, @alias, @seeds, @gossip_val, @health_check_val, @heartbeat_val, @reduce_val} = {}) ->
    assert.notEqual @seeds.length, 0
    assert.ok @gossip_val >= 1000
    assert.ok @health_check_val >= 1000
    
    @id = "#{@addr}:#{@port}"
    @unreachable = []
    @alive = []
    @peers = {}
    @state = new State {@id}
    @scuttlebutt = new ScuttleButt @state, @peers
    @__heartbeat = 0
    super()

  run: ->
    @initSeeds()
    @initPeers()
    @initHandlers()
    @serve()
    @heartbeat()
    @polling()
    @monitor()
    # @reduce()
    
  initSeeds: ->
    util.unorderList.rm @seeds, @id
    log "init seeds:", @seeds

  initPeers: ->
    new_peers = for id in @seeds
      @alive.push id
      @peers[id] = new Peer {id}
      id

    setImmediate =>
      @emit "new_peers", new_peers if new_peers.length
    
    log "init peers:", @peers

  serve: ->
    @server = net.createServer (socket) =>
      decodeStream = msgpack.createDecodeStream()
      encodeStream = msgpack.createEncodeStream()
      
      messageHandle = @onMsg.bind this, {ms: encodeStream}
      
      encodeStream
      .pipe socket
      .pipe decodeStream
      .on 'data', messageHandle
      
      socket.on 'error', (e) -> log e
        
      # TODO: initialize server events handle configuration
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
    unhealth = []
    alive = []
    for peer_info, peer of @peers
      [source, target] = if peer.detect util.curr_ts()
        alive.push peer_info unless peer.isAlive
        peer.isAlive = yes
        [@unreachable, @alive]
      else
        unhealth.push peer_info if peer.isAlive
        peer.isAlive = no
        [@alive, @unreachable]

      util.unorderList.rm source, peer_info
      target.push peer_info unless peer_info in target
      console.info "\t", peer_info, "is alive:", peer.isAlive, "alive:", @alive, "suspent:", @unreachable
    
    @emit 'new_alive_peers', alive if alive.length
    @emit 'new_suspect_peers', unhealth if unhealth.length

  schedule: (callback) ->
    # log "start schedule peers"
    # console.log @peers
    queue = []
    # TODO: schedule with a probablity
    if @alive.length > 0
      queue.push util.getRandomItem @alive
      
    if @unreachable.length > 0
      queue.push util.getRandomItem @unreachable
      
    if (queue[0] not in @seeds and @seeds.length > 0) or @alive.length < @seeds.length
      queue.push util.getRandomItem @seeds
    
    # log "peers to gossip with:", queue
    return callback() if queue.length is 0

    queue = for peer_info in queue
      [addr, port] = peer_info.split ':'
      (cb) => @gossip addr, port, cb

    # TODO: consider if there is need to wait the longest request
    async.parallel queue, (err, done) ->
      callback()

  gossip: (peer_addr, peer_port, callback) =>
    # TODO: client events handle configuration
    socket = net.connect peer_port, peer_addr
    .on 'error', (e) => 
      log e.message
      callback null
    .on 'connect', =>
      decodeStream = msgpack.createDecodeStream()
      encodeStream = msgpack.createEncodeStream()
      messageHandle = @onMsg.bind this, {ms: encodeStream, callback}
      encodeStream
      .pipe socket
      .pipe decodeStream
      .on 'data', messageHandle 
      
      log "gossip with", peer_addr, peer_port
      encodeStream.write @scuttlebutt.yieldDigest()
      # ms.send @scuttlebutt.yieldDigest()

  onMsg: (opt, msg) =>
    {ms} = opt
    switch msg.type
      when 'pull_digest'
        @emit '_digest', ms, msg.digest
      when 'pull_deltas'
        @emit '_deltas', ms, msg.deltas, msg.digest, opt.callback
      when 'push_deltas'
        @emit '_push_deltas', ms, msg.deltas
      when 'delete'
        @emit '_delete', ms, msg.key
      else
        console.error 'unexpected pack'

  initHandlers: ->
    @on '_digest', (ms, digest) ->      
      ms.write @scuttlebutt.yieldPullDeltas digest

    @on '_deltas', (ms, deltas, digest, done) ->
      # update new k-v in state
      [new_peers, updates] = @scuttlebutt.updateDeltas deltas
      @alive.push new_peers...
      # send push deltas request
      ms.write @scuttlebutt.yieldPushDeltas digest
      ms.end()

      setImmediate =>
        @emit 'new_peers', new_peers if new_peers.length
        @emit 'updates', updates if updates.length

      done null

    @on '_push_deltas', (ms, deltas) ->
      # update new k-v in state
      [new_peers, updates] = @scuttlebutt.updateDeltas deltas
      @alive.push new_peers...
      # console.log new_peers
      setImmediate =>
        @emit 'new_peers', new_peers if new_peers.length
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
