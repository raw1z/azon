Command = require('./command') 

class Runner
  constructor: ->
    @command = new Command.NewTaskCommand()
    @command.link new Command.ChangeTaskCommand()
    @command.link new Command.CloseTaskCommand()

  run: (name, bucketName, taskId, value) ->
    @command.run(name, bucketName, taskId, value)

exports.Runner = Runner
