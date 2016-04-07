{EventEmitter} = require 'events'

util = require './util'

class State extends EventEmitter

  constructor: (info) ->
    {@id, @addr, @port} = info
    @data = {}
    @_trash = []
    @max_version = @defaultVersion()

  defaultVersion: -> 0

  set: (k, v) ->
    @max_version += 1
    @data[k] = [v, @max_version]

  get: (k) ->
    @data[k]

  getv: (k) ->
    @data[k]?[0]

  getn: (k) ->
    @date[k]?[1] ? @defaultVersion()

  geta: ->
    @data

  delh: (k) ->
    delete @data[k]
    util.unorderList.rm @_trash, k

  dels: (k) ->
    @data[k]?.needDelete = yes
    @_trash.push k unless k in @_trash

module.exports = State
