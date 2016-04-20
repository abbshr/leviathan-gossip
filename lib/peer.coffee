util = require './util'
FailureDetector = require './detect'

class Peer

  constructor: ({id} = {}) ->
    @state ?= new State id
    @detector = new FailureDetector last_contact_ts: util.curr_ts()
    @isAlive = yes
    @__heartbeat = 0

  detect: (ts) ->
    @detector.detect ts
    
  accural: (ts) ->
    @detector.accural ts