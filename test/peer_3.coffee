Gossip = require '../lib'
cfg =
  alias: "node#03"
  seeds: ["127.0.0.1:3000"]
  addr: "127.0.0.1"
  port: 3002
  gossip_val: 1000
  heartbeat_val: 1000
  health_check_val: 10 * 1000

gossip = new Gossip cfg
gossip.run()

gossip.set "k3", "v3"
gossip.set "p3", "v3"

gossip.on "new_peers", (peers) ->
  console.log "found new peers:", peers
gossip.on "updates", (deltas) ->
  console.log "get updates:", deltas
  console.log "peer_2:", gossip.peers["127.0.0.1:3001"]?.state
  console.log "peer_1:", gossip.peers["127.0.0.1:3000"]?.state
