net = require 'net'
assert = require 'assert'
{EventEmitter} = require 'events'

util = require 'archangel-util'
msgpack = require 'msgpack'
async = require 'async'

Scuttlebutt = require './scuttlebutt'
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
    
    @id = "#{addr}:#{port}"
    @unreachable = []
    @alive = []
    @peers = {}
    @state = new State @id
    @scuttlebutt = new ScuttleButt @state, @peers
    @__heartbeat = 0
    super()

  run: ->
    @initPeers()
    @initHandlers()
    @serve()
    @heartbeat()
    @polling()
    @monitor()
    @reduce()

  initPeers: ->
    for peer_info in @seeds
      @alive.push peer_info
      @peer[peer_info] = new Peer peer_info

  serve: ->
    @server = net.createServer (socket) =>
      ms = new msgpack.Stream socket
      messageHandler = @onMsg.bind this, {ms}
      ms.on 'msg', messageHandle
      # TODO: initialize server events handle configuration
    .listen @port

  heartbeat: ->
    @state.set "__heartbeat", ++@__heartbeat
    setTimeout =>
      @heartbeat()
    , @heartbeat_val

  polling: =>
    # TODO: consider if there is need to wait the longest request
    setTimeout =>
      @schedule @polling
    , @gossip_val

  monitor: ->
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
    for peer_info, peer of @peers
      [source, target] = if peer.detect util.curr_ts()
        peer.isAlive = yes
        [@unreachable, @alive]
      else
        peer.isAlive = no
        [@alive, @unreachable]

      util.unorderList.rm source, peer_info
      target.push peer_info unless peer_info in target

  schedule: (callback) ->
    queue = []
    # TODO: schedule with a probablity
    if @alive > 0
      queue.push util.getRandomPeer @alive
      if queue[0] not in @seeds or @alive.length < @seeds.length
        queue.push util.getRandomPeer @seeds
    if @unreachable > 0
      queue.push util.getRandomPeer @unreachable

    return if queue.length is 0

    queue = for peer_info in queue
      [addr, port] = peer_info.split ':'
      (cb) -> @gossip addr, port, cb

    # TODO: consider if there is need to wait the longest request
    async.parallel queue, (err, done) ->
      callback()

  gossip: (peer_addr, peer_port, callback) =>
    # TODO: client events handle configuration
    peer = net.connect peer_addr, peer_port
    ms = new msgpack.Stream peer

    messageHandler = @onMsg.bind this, {ms, callback}

    peer.on 'error', onError
    ms.on 'msg', messageHandler

    ms.send @scuttlebutt.yieldDigest()

  onMsg = (opt, msg) =>
    {ms} = opt
    switch msg.type
      when 'pull_digest'
        @emit '_digest', ms, msg.digest
      when 'pull_deltas'
        @emit '_deltas', ms, msg.deltas, msg.digest, opt.callback
      when 'push_deltas'
        @emit '_push_deltas', ms, msg.deltas, opt.callback
      when 'delete'
        @emit '_delete', ms, msg.key
      else
        console.error 'unexpected pack'

  initHandlers: ->
    @on '_digest', (ms, digest) ->
      ms.send @scuttlebutt.yieldPullDeltas digest

    @on '_deltas', (ms, deltas, digest, done) ->
      delete digest[@state.id]
      # update new k-v in state
      new_peers = @scuttlebutt.updateDeltas deltas
      # send push deltas request
      ms.send @scuttlebutt.yieldPushDeltas digest
      # TODO: msgpack stream
      ms.end()

      setImmediate =>
        @emit 'new_peers', new_peers if new_peers.length
        @emit 'updates', deltas if deltas.length

      done null

    @on '_push_deltas', (ms, deltas, done) ->
      delete digest[@state.id]
      # update new k-v in state
      new_peers = @scuttlebutt.updateDeltas deltas
      
      setImmediate =>
        @emit 'new_peers', new_peers if new_peers.length
        @emit 'updates', deltas if deltas.length
      
      done null

    # TODO: spread delete command
    # @on '_delete', (ms, key) ->
    #   @state.dels key

  set: (k, v) ->
    @state.set k, v
    
  get: (r, k) ->
    state = if r is @state.id
      @state
    else
      @peers[r].state
    state.getv k
    
  getn: (r, k) ->
    state = if r is @state.id
      @state
    else
      @peers[r].state
    state.getn k
    
  # TODO: spread delete command
  # del: (k) ->
  #   @state.dels k

module.exports = Gossip
