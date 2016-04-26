assert = require 'assert'
util = require 'archangel-util'
State = require './state'
FailureDetector = require './detect'

# parameters
# @cfg = hash
#   required: id
class Peer

  constructor: ({@id, @state, opt = {}} = {}) ->
    @state = new State {@id} unless @state?
    
    @detector = new FailureDetector opt
    @isActive = yes
    @__heartbeat = 0

  detect: (ts) ->
    @detector.detect ts
    
  accural: (ts) ->
    @detector.accural ts

module.exports = Peer