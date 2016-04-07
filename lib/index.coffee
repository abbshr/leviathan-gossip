net = require 'net'
assert = require 'assert'
{EventEmitter} = require 'events'

msgpack = require 'msgpack'
async = require 'async'

scuttlebutt = require './scuttlebutt'
FailureDetector = require './detect'
util = require './util'
State = require './state'

class Gossip extends EventEmitter

  # parameters

  # @@seeds:
  # @@id:
  # @@addr:
  # @@port:
  # @@gossip_val:
  # @@heartbeat_val:
  # @@health_check_val:
  # @@reduce_val:
  constructor: (args) ->
    {@seeds, @gossip_val, @health_check_val, @heartbeat_val, @reduce_val} = args

    assert.notEqual @seeds.length, 0
    assert.ok @gossip_val >= 1000
    assert.ok @health_check_val >= 1000

    @unreachable = []
    @alive = []
    @peers = {}
    @state = new State args.id, args.addr, args.port
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
      @peers[peer_info] = new FailureDetector last_contact_ts: util.curr_ts()
      @peers[peer_info].isAlive = yes
      @peers[peer_info].__heartbeat = 0

  serve: ->
    net.createServer (socket) =>
      ms = new msgpack.Stream socket
      messageHandler = @onMsg.bind this, {ms}
      ms.on 'msg', messageHandle
      # TODO: initialize server events handle configuration

  heartbeat: ->
    @__heartbeat++
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
  reduce: ->
    setTimeout =>
      @state.delh k for k in @state._trash
      @reduce()
    , @reduce_val

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
        @emit '_deltas', ms, msg.digest, msg.state, opt.callback
      when 'push_deltas'
        @emit '_push_deltas', ms, msg.state, opt.callback
      when 'delete'
        @emit '_delete', ms, msg.key
      else
        console.error 'unexpected pack'

  initHandlers: ->
    @on '_digest', (ms, digest) ->
      # update known-peers list
      @scuttlebutt.updatePeers digest.peers
      ms.send @scuttlebutt.yieldPullDeltas digest

    @on '_deltas', (ms, {peers, version}, deltas, done) ->
      # update known-peers list
      @scuttlebutt.updatePeers peers
      # update new k-v in state
      @scuttlebutt.updateDeltas deltas
      # send push deltas request
      ms.send @scuttlebutt.yieldPushDeltas deltas
      # TODO: msgpack stream
      ms.end()

      setImmediate =>
        @emit 'new_peers', Object.keys peers if peers.length
        @emit 'updates', deltas if deltas.length

      done null

    @on '_push_deltas', (ms, deltas, done) ->
      # update new k-v in state
      @scuttlebutt.updateDeltas deltas
      done()

    # TODO: spread delete command
    @on '_delete', (ms, key) ->
      @state.dels key

  set: (k, v) ->
    @state.set k, v, @versionGenerator @getn k
  get: (k) ->
    @state.getv k
  getn: (k) ->
    @state.getn k
  # TODO: spread delete command
  del: (k) ->
    @state.dels k

  # custom version-update strategy
  versionGenerator: (curr_version) ->
    curr_version + 1 if curr_version?

module.exports = Gossip
