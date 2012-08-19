Command = require('./command') 

class Runner
  constructor: ->
    @command = Command.root

  run: (name, bucketName, taskId, value) ->
    @command.run(name, bucketName, taskId, value)

exports.Runner = Runner
