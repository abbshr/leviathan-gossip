# accural failure detector
util = require './util'
class FailureDetector

  constructor: (info) ->
    {@id, @phi, @last_contact_ts} = info
    @val = []
    @threshold = 8
    @val_max_len = 100

  accural: (curr_ts) ->
    @val.push curr_ts - @last_contact_ts
    @val.shift() if @val.length > @val_max_len
    @last_contact_ts = curr_ts

  detect: (curr_ts) ->
    val = curr_ts - last_contact_ts
    e = val / util.means @val
    @phi = e / Math.log 10
    @phi <= @threshold

module.exports = FailureDetector
