{EventEmitter} = require 'events'
dgram = require 'dgram'
net = require 'net'
msgpack = require 'msgpack'

class Gossip extends EventEmitter

  constructor: (args = {}) ->
    @local = "127.0.0.1:#{port}"
    {@port, @secval, @alive, @seeds} = args
    @node = dgram.createSocket 'udp4'
    @_initSocket @node
    @_init()
    super()

  _initSocket: (socket) ->
    socket
    .on 'message', onMessage
    .on 'error', onError
    .on 'close', onClose

  _init: ->
    if @local in @seeds
      @on 'joining', (data) =>
        {address: ip, port} = data.rinfo
        console.log "[joining cluster - node:]", ip, port
        @alive.push "#{ip}:#{port}"
        info = Buffer JSON.stringify type: 'joined'
        push ip, port, info

    unless @local in @seeds
      @on 'joined', (data) =>
        clearTimeout @ref
        {address: ip, port} = data.rinfo
        console.log 'joined cluster'
        @alive.push "#{ip}:#{port}"

    @on 'pull-alive-nodes', (data) =>
      {address: ip, port} = data.rinfo
      console.warn 'pull request from', ip, port
      # calcute the diff part
      Object.assign @alive, data.alive
      res = Buffer JSON.stringify type: 'push-alive-nodes', data: alive: @alive
      @push ip, port, res

    @on 'push-alive-nodes', (data) =>
      {address: ip, port} = data.rinfo
      console.warn 'pull from', ip, port
      Object.assign @alive, data.alive
      @emit "polling"

  onMessage: (msg, rinfo) ->
    event = JSON.parse msg.toString 'utf-8'
    {type} = event
    event.data.rinfo = rinfo
    @emit type, event.data
  onError: (err) -> console.error err
  onClose: -> console.warn 'local socket closed'

  onPolling: ->
    clearTimeout @_pollref
    @_ref = setTimeout =>
      spread()
    , @secval * 1000

  run: ->
    stateInfo = Buffer JSON.stringify type: 'joining', data: local
    @node.bind @port, =>
      @join @seeds, stateInfo unless local in @seeds
      spread()

  # polling: =>
  #   @_ref = setTimeout =>
  #     spread @polling
  #   , @secval * 1000

  randomNode: (type) ->
    rand = Math.random()
    switch type
      when 'seed' then @seeds[rand * @seeds.length >> 0]
      when 'alive' then @alive[rand * @alive.length >> 0]
      when 'unreachable' then @unreachable[rand * @unreachable.length >> 0]

  spread: ->
    if @alive.length > 0
      liveNode = @randomNode 'alive'
      @sync liveNode
    if @unreachable.length > 0
      unreachedNode = @randomNode 'unreachable'
      @sync unreachedNode

    if liveNode not in @seeds or @alive.length < @seeds.length
      seedNode = @randomNode 'seed'
      @sync seedNode

    @once 'polling', @onPolling
    @_pollref = setTimeout =>
      @removeListener 'polling', @onPolling if @listenerCounts 'polling' > 0
      @spread()
    , 20 * 1000

  sync: (node) ->
    dataSet = Buffer JSON.stringify type: 'pull-alive-nodes', data: alive: @alive
    [ip, port] = node.split ':'
    @pull ip, port, dataSet

  pull: (ip, port, keys) ->
    @node.send keys, port, ip

  push: (ip, port, dataSet) ->
    @node.send dataSet, port, ip

  join: (seeds, stateInfo) ->
    if seeds.length is 0
      return no
    [ip, port] = seeds[0].split ':'
    @node.send stateInfo, port, ip
    @ref = setTimeout =>
      @join seeds[1..], stateInfo
    , 10 * 1000

module.exports = Gossip
