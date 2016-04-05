# liveness detector

detect = (last_contact_ts, curr_ts) ->
  diff = curr_ts - last_contact_ts
  switch
  when 0 < diff < 5 * 1000
    # health: normal/alive
  when 5 * 1000 <= diff < 10 * 1000
    # health: con/dying
  when diff >= 1000 * 10
    # health: unreachable/dead

class FailureDetector

  constructor: (info) ->
    {@id, @phi, @last_contact_ts} = info

  acc: (val, curr_ts) ->

  detect: (val, curr_ts) ->

module.exports = FailureDetector
