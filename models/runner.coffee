Command = require('./command') 

class Runner
  constructor: ->
    @command = new Command.EmptyCommand()
    @command.link new Command.NewTaskCommand()

  run: (name, target, value) ->
    @command.run(name, target, value)


exports.Runner = Runner
