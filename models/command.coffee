Logger = require('./logger').Logger
Task = require("./task").Task

class Command
  constructor: (name, aliases..., logic) ->
    @name = name
    @aliases = aliases
    @logic = logic
    @next = null

  link: (next) ->
    if @next is null
      @next = next
    else
      @next.link next

  run: (name, target, value) ->
    if (@name is name) or (@aliases.indexOf(name) isnt -1)
      @logic(target, value)
    else
      @next?.run(name, target, value)

class EmptyCommand extends Command
  constructor: ->
    super ':', (target, value) ->
      Logger.info 'Empty command'
        target: target
        value: value

class NewTaskCommand extends Command
  constructor: ->
    super ':new', ':n', (target, value) ->
      bucket = switch target
        when '@1' then 'today'
        when '@2' then 'tomorrow'
        when '@3' then 'twoDaysFromNow'
        when '@4' then 'future'

      task = new Task
        description: value
        bucket: bucket
        createdAt: Date.now()

      task.save (err) ->
        if err
          Logger.alert err
        else
          global.io.sockets.emit 'update bucket', bucket

exports.EmptyCommand = EmptyCommand
exports.NewTaskCommand = NewTaskCommand
