{EventEmitter} = require 'events'
util = require 'archangel-util'
Peer = require './peer'
FailureDetector = require './detect'

class ScuttleButt extends EventEmitter

  constructor: (state, peers) ->
    @state = state
    @peers = peers

  yieldDigest: ->
    {id: local_id, max_version: local_max_version} = @state
    
    digest = {}
    for _, peer of @peers
      {id, max_version} = peer.state
      digest[id] = max_version
    digest[local_id] = local_max_version
    
    # console.log "gossiper yield Digest:", digest
    
    {type: 'pull_digest', digest}

  yieldPullDeltas: (digest) ->
    # console.log "gossipee receive Digest:", digest 
    receipt = {}
    deltas = []
    defaultVersion = @state.defaultVersion()
    for id, version of digest
      switch
        when id is @state.id
          if version < @state.max_version
            deltas.push (@_yieldUpdate version, @state)...
        when not @peers[id]?
          receipt[id] = defaultVersion
        when @peers[id].state.max_version > version
          deltas.push (@_yieldUpdate version, @peers[id].state)...
        when @peers[id].state.max_version < version
          receipt[id] = @peers[id].state.max_version
    
    delete digest[@state.id]
    for id, peer of @peers when id not of digest
      deltas.push (@_yieldUpdate defaultVersion, @peers[id].state)...
    
    # console.log "gossipee yield Deltas:", deltas
    # console.log "gossipee yield New Digest:", receipt

    {type: 'pull_deltas', deltas, receipt}

  yieldPushDeltas: (receipt) ->
    # console.log "gossiper receive Receipt:", receipt
    # delete receipt[@state.id]
    
    deltas = []
    for id, version of receipt
      deltas.push (@_yieldUpdate version, @peers[id]?.state ? @state)...
    
    # console.log "gossiper yield Deltas:", deltas
    {type: 'push_deltas', deltas}

  _yieldUpdate: (version, state) ->
    ([state.id, k, v, n] for k, [v, n] of state.data when n > version)
    .sort ([..., n_a], [..., n_b]) -> n_a - n_b

  applyUpdate: (deltas) ->
    updates = []
    new_peers = for [id, k, v, n] in deltas
      existed = yes
      unless @peers[id]?
        existed = no
        @peers[id] = new Peer {id}
        
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