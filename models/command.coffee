Logger = require('./logger').Logger
Task = require("./task").Task

class Command
  constructor: (name, aliases..., logic) ->
    @name = name
    @aliases = aliases
    @logic = logic
    @next = null

  link: (next) ->
    if @next
      @next.link next
    else
      @next = next

  getBucket: (name) ->
    switch name
      when '@1' then 'today'
      when '@2' then 'tomorrow'
      when '@3' then 'twoDaysFromNow'
      when '@4' then 'future'
      else name

  run: (name, bucketName, taskId, value) ->
    if (@name is name) or (@aliases.indexOf(name) isnt -1)
      @logic(@getBucket(bucketName), taskId, value)
    else
      @next?.run(name, bucketName, taskId, value)

class NewTaskCommand extends Command
  constructor: ->
    super ':new', ':n', (bucket, taskId, value) ->
      task = new Task
        description: value
        bucket: bucket
        createdAt: Date.now()

      task.save (err) ->
        if err
          Logger.alert err
        else
          global.io.sockets.emit 'update bucket', bucket

class ChangeTaskCommand extends Command
  constructor: ->
    super ':change', ':ch', (bucket, taskId, value) ->
      Task.findOneAndUpdate { _id: taskId }, { description: value }, (err, task) ->
        if err
          Logger.alert err
        else
          global.io.sockets.emit 'update bucket', bucket

class CloseTaskCommand extends Command
  constructor: ->
    super ':close', ':cl', (bucket, taskId, value) ->
      Task.findOneAndUpdate { _id: taskId }, { bucket: 'done' }, (err, task) ->
        if err
          Logger.alert err
        else
          global.io.sockets.emit 'update bucket', bucket

exports.NewTaskCommand = NewTaskCommand
exports.ChangeTaskCommand = ChangeTaskCommand
exports.CloseTaskCommand = CloseTaskCommand
