{EventEmitter} = require 'events'

failureDetector = require './detect'
util = require './util'

# TODO: remove peers opts, just for pure ScuttleButt
class ScuttleButt extends EventEmitter

  constructor: (state, peers) ->
    @state = state
    @peers = peers

  yieldDigest: ->
    type: 'pull_digest'
    digest:
      id: @state.id
      peers: Object.keys @peers
      version: @state.max_version

  yieldPullDeltas: (digest) ->
    {id, peers, version} = digest

    type: 'pull_deltas'
    id: @state.id
    digest:
      peers: peer_info for peer_info of @peers when peer_info not in peers
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
    for peer_info in peers when peer_info not of @peers
      @peers[peer_info] = phi: 0, last_contact_ts: util.curr_ts()
    # emit at up level

  updateDeltas: (state) ->
    @state.set k, v, n for [k, v, n] in state
    # emit at up level
