class Logger
  @warn: (message) ->
    @log 'warning', message, 'success'

  @alert: (message) ->
    @log 'error', message, 'failure'

  @notice: (message) ->
    @log 'notice', message, 'success'

  @info: (message) ->
    @log 'info', message, 'success'

  @log : (level, message, status) ->
    global.io.sockets.emit "log #{level}", data: message
    res.send status: status

exports.Logger = Logger
