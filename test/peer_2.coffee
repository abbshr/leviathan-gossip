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