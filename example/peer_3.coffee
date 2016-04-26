Gossip = require '../lib'
cfg =
  alias: "node#03"
  seeds: ["127.0.0.1:3000","127.0.0.1:3003"]
  addr: "127.0.0.1"
  port: 3002
  gossip_val: 1000
  heartbeat_val: 1000
  health_check_val: 10 * 1000

gossip = new Gossip cfg
gossip.run()

gossip.set "k3", "v3"
gossip.set "p3", "v3"

gossip.on "peers_discover", (peers) ->
  console.log "found new peers:", peers
gossip.on "peers_recover", (peers) ->
  console.log "peers become active:", peers
gossip.on "peers_suspend", (peers) ->
  console.log "peers become suspend:", peers
gossip.on "updates", (deltas) ->
  console.log "get updates:", deltas