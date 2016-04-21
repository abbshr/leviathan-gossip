assert = require 'assert'
util = require 'archangel-util'
FailureDetector = require './detect'

# parameters
# @cfg = hash
#   required: id
class Peer

  constructor: ({id} = {}) ->
    assert.ok id?
    @state ?= new State id
    @detector = new FailureDetector last_contact_ts: util.curr_ts()
    @isAlive = yes
    @__heartbeat = 0

  detect: (ts) ->
    @detector.detect ts
    
  accural: (ts) ->
    @detector.accural ts