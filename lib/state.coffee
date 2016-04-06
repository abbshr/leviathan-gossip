{EventEmitter} = require 'events'

level = require './persistent'
util = require './util'

class State extends EventEmitter

  constructor: (info) ->
    {@id, @addr, @port} = info
    @data = {}
    @_trash = []
    @max_version = @defaultVersion()

  defaultVersion: -> 0

  set: (k, v, n = @defaultVersion()) ->
    @data[k] = [v, n]
    @max_version = n if n > @max_version
  get: (k) ->
    @data[k]
  geta: ->
    @data
  delh: (k) ->
    delete @data[k]
    util.unorderList.rm @_trash, k
  dels: (k) ->
    @data[k]?.needDelete = yes
    @_trash.push k unless k in @_trash

module.exports = State
