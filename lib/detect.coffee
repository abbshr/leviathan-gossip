# accural failure detector
util = require 'archangel-util'

class FailureDetector

  constructor: ({@last_contact_ts = util.curr_ts(), @phi_threshold = 6, @val_max_len = 100} = {}) ->
    @val = []

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
      
    p_later = Math.pow Math.E, (-val / means)
    
    # phi calculate method learn from cassandra...
    phi = -Math.log10 p_later 
    phi <= @phi_threshold

module.exports = FailureDetector
