Command = require('./command') 

class Runner
  constructor: ->
    @command = Command.root

  run: (env) ->
    @command.run(env)

exports.Runner = Runner
