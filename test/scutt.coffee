# for console debug use
ScuttleButt = require '../lib/scuttlebutt'
Peer = require '../lib/peer'
State = require '../lib/state'

global.own_state = new State id: "localhost:2333"

global.peers = {}

for i in [1..20]
  id = "#{i * 1000}:2333"
  peer = new Peer {id}
  peers[id] = peer

global.scuttle = new ScuttleButt own_state, peers

own_state.set "name", "ran"
own_state.set "age", 22
own_state.set "love", "coding"
