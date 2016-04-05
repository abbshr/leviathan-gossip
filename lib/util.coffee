assert = require 'assert'

exports.curr_ts = ->
  Date.now()

exports.getRandomPeer = (peers) ->
  assert.ok peers.length
  rand = Math.random()
  peers[rand * peers.length >> 0]

exports.unorderList =
  rm: (lst, pos) ->
    len = lst.length
    return unless len

    idx = lst.indexOf pos
    return unless !!~idx

    last = lst.pop()
    lst[idx] = last unless idx is len - 1
