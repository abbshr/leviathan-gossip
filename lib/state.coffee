{EventEmitter} = require 'events'
util = require 'archangel-util'

class State extends EventEmitter

  constructor: (info) ->
    {@id} = info
    @data = {}
    # @_trash = []
    @max_version = @defaultVersion()

  defaultVersion: -> 0
  
  set: (k, v, n) ->
    version = n ? @max_version + 1
    @max_version = if n > @max_version then n else @max_version + 1
    @data[k] = [v, version]
    @max_version

  get: (k) ->
    @data[k]

  getv: (k) ->
    @data[k]?[0]

  getn: (k) ->
    @data[k]?[1] ? @defaultVersion()

  # geta: ->
  #   @data

  # delh: (k) ->
  #   delete @data[k]
  #   util.unorderList.rm @_trash, k

  # dels: (k) ->
  #   @data[k]?.needDelete = yes
  #   @_trash.push k unless k in @_trash

module.exports = State
