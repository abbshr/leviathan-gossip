# accural failure detector
util = require 'archangel-util'

class FailureDetector

  constructor: (info) ->
    {@id, @last_contact_ts} = info
    @val = []
    @threshold = 8
    @val_max_len = 100

  accural: (curr_ts) ->
    @val.push curr_ts - @last_contact_ts
    @val.shift() if @val.length > @val_max_len
    @last_contact_ts = curr_ts

  detect: (curr_ts) ->
    val = curr_ts - @last_contact_ts
    means = if @val.length
      util.means @val
    else
      Infinity
    e = val / means
    e / Math.log 10 <= @threshold

module.exports = FailureDetector
