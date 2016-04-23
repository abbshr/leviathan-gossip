Gossip = require '../lib'
cfg =
  alias: "node#01"
  seeds: ["127.0.0.1:3000"]
  addr: "127.0.0.1"
  port: 3000
  gossip_val: 1000
  heartbeat_val: 1000
  health_check_val: 10 * 1000

gossip = new Gossip cfg
gossip.run()