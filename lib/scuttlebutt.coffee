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
    for peer of @peers
      {id, max_version} = peer.state
      digest[id] = max_version
    digest[local_id] = local_max_version
    
    {type: 'pull_digest', digest}

  yieldPullDeltas: (digest) ->
    new_digest = {}
    deltas = []
    for id, version of digest
      if @peers[id]?.state.version > version
        deltas.push (@_yieldUpdate version, @peers[id].state)...
      else if @peers[id]?.state.version isnt version
        new_digest[id] = @peers[id].state.max_version
    
    defaultVersion = @state.defaultVersion()
    for peer_info, peer of @peers when peer_info not of digest
      deltas.push (@_yieldUpdate defaultVersion, @peers[id].state)...

    {type: 'pull_deltas', deltas, digest: new_digest}

  yieldPushDeltas: (digest) ->
    deltas = []
    for id, version of digest
      deltas.push (@_yieldUpdate version, @peers[id].state)...
      
    {type: 'push_deltas', deltas}

  _yieldUpdate: (version, state) ->
    ([state.id, k, v, n] for k, [v, n] of state.data when n > version)
    .sort ([..., n_a], [..., n_b]) -> n_a - n_b

  updateDeltas: (deltas) ->
    for [id, k, v, n] in deltas when n > @state.getn k
      unless @peers[id]?
        existed = no 
        @peers[id] = new Peer {id}
      
      if k is '__heartbeat' and v > @peers[id].__heartbeat
        @peers[id].__heartbeat = v
        @peers[id].accural util.curr_ts()
        
      @peers[id].state.set k, v, n
      if existed then continue else id