Gossip = require '../lib'
cfg =
  alias: "node#02"
  seeds: ["127.0.0.1:3000"]
  addr: "127.0.0.1"
  port: 3001
  gossip_val: 1000
  heartbeat_val: 1000
  health_check_val: 10 * 1000

gossip = new Gossip cfg
gossip.run()

gossip.set "k2", "v2"
gossip.set "p2", "v2"

gossip.on "new_peers", (peers) ->
  console.log "found new peers:", peers
gossip.on "updates", (deltas) ->
  console.log "get updates:", deltas
  console.log "peer_1:", gossip.peers["127.0.0.1:3000"]?.state
  console.log "peer_3:", gossip.peers["127.0.0.1:3002"]?.state
