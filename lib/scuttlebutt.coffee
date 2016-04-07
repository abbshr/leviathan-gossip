{EventEmitter} = require 'events'

FailureDetector = require './detect'
util = require './util'

# TODO: remove peers opts, just for pure ScuttleButt
class ScuttleButt extends EventEmitter

  constructor: (state, peers) ->
    @state = state
    @peers = peers

  yieldDigest: ->
    peers = {}
    peers[peer_info] = __heartbeat for peer_info, {__heartbeat} of @peers

    type: 'pull_digest'
    digest:
      id: @state.id
      peers: peers
      version: @state.max_version

  yieldPullDeltas: (digest) ->
    {id, peers, version} = digest
    local_peers = {}
    for peer_info, {__heartbeat} of @peers when peer_info not of peers
      local_peers[peer_info] = __heartbeat

    type: 'pull_deltas'
    id: @state.id
    digest:
      peers: local_peers
      version: @state.max_version
    state: @_yieldUpdate version

  yieldPushDeltas: (deltas) ->
    {id, digest} = deltas

    type: 'push_deltas'
    id: @state.id
    state: @_yieldUpdate digest.version

  _yieldUpdate: (version) ->
    if version < @state.max_version
      ([k, v, n] for k, [v, n] of @state.data when n > version)
      .sort ([..., n_a], [..., n_b]) -> n_a - n_b
    else
      []

  updatePeers: (peers) ->
    for peer_info, __heartbeat of peers

      if peer_info not of @peers
        @peers[peer_info] = new FailureDetector last_contact_ts: util.curr_ts()
        @peers[peer_info].isAlive = yes
        @peers[peer_info].__heartbeat = __heartbeat

      if __heartbeat > @peers[peer_info].__heartbeat
        @peers[peer_info].__heartbeat = __heartbeat
        @peers[peer_info].accural util.curr_ts()

  updateDeltas: (state) ->
    @state.set k, v, n for [k, v, n] in state when n > @state.getn k
