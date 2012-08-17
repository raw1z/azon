class Logger
  @warn: (message) ->
    @log 'warning', message

  @alert: (message) ->
    @log 'error', message

  @notice: (message) ->
    @log 'notice', message

  @info: (message) ->
    @log 'info', message

  @log : (level, message) ->
    global.io.sockets.emit "log #{level}", data: message

exports.Logger = Logger
