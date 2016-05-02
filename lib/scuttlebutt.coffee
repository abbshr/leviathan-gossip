{EventEmitter} = require 'events'
util = require 'archangel-util'
Peer = require './peer'

class ScuttleButt extends EventEmitter

  constructor: (state, peers, @opt = {}) ->
    @state = state
    @peers = peers

  yieldDigest: ->
    {id: local_id, max_version: local_max_version} = @state
    
    digest = {}
    digest[id] = max_version for _, {state: {id, max_version}} of @peers
    digest[local_id] = local_max_version
    # console.info "gossiper yieldDigest:", digest
    {id: local_id, type: 'pull_digest', digest}

  yieldPullDeltas: (remote_id, digest) ->
    # console.info "gossipee receive digest:", digest
    receipt = {}
    deltas = []
    defaultVersion = @state.defaultVersion()
    
    # as gossipee
    if _local_version = digest[@state.id]
      delete digest[@state.id]
      if _local_version < @state.max_version
        deltas.push (@_yieldUpdate _local_version, @state)...
      else if _local_version > @state.max_version
        @state.set '__heartbeat', 1, _local_version + 1
        deltas.push [@state.id, '__heartbeat', 1, _local_version + 1]

    for id, version of digest
      max_version = @peers[id]?.state.max_version
      switch
        when not @peers[id]?
          receipt[id] = defaultVersion
        when max_version > version
          if id is remote_id
            deltas.push [id, '__heartbeat', 1, max_version + 1]
          else
            deltas.push (@_yieldUpdate version, @peers[id].state)...
        when @peers[id].state.max_version < version
          receipt[id] = @peers[id].state.max_version
    
    for id, peer of @peers when id not of digest
      deltas.push (@_yieldUpdate defaultVersion, @peers[id].state)...
    
    # console.info "gossipee yieldDeltas:", deltas
    # console.info "gossipee yieldReceipt:", receipt
    {type: 'pull_deltas', deltas, receipt}

  yieldPushDeltas: (receipt) ->
    # console.info 'gossiper receive receipt:', receipt
    deltas = []
    for id, version of receipt
      deltas.push (@_yieldUpdate version, @peers[id]?.state ? @state)...
    
    {type: 'push_deltas', deltas}

  _yieldUpdate: (version, state) ->
    ([state.id, k, v, n] for k, [v, n] of state.data when n > version)
    .sort ([..., n_a], [..., n_b]) -> n_a - n_b

  applyUpdate: (deltas) ->
    # console.log deltas
    updates = []
    new_peers = for [id, k, v, n] in deltas
      existed = yes
      if id is @state.id
        if k is '__heartbeat' and n > @state.getn k
          @state.set '__heartbeat', v, n
        continue
      else if id not of @peers
        existed = no
        @peers[id] = new Peer {id, @opt}
        
      if n > @peers[id].state.getn k
        @peers[id].state.set k, v, n
        if k is '__heartbeat'
          @peers[id].__heartbeat = v
          @peers[id].accural util.curr_ts()
        else
          updates.push [id, k, v, n]

      if existed then continue else id
      
    [new_peers, updates]
      
module.exports = ScuttleButt