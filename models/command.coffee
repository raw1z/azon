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
      when '@5' then 'done'
      when '@6' then 'trash'
      else name

  run: (name, bucketName, taskId, value) ->
    if (@name is name) or (@aliases.indexOf(name) isnt -1)
      @logic(@getBucket(bucketName), taskId, value)
    else
      @next?.run(name, bucketName, taskId, value)

  notifyBucketUpdate: (name, updatedTask) ->
    global.io.sockets.emit 'update bucket', bucket: name, updatedTask: updatedTask

class RootCommand extends Command
  constructor: ->
    self = this
    super ':', (bucket, taskId, value) ->

class NewTaskCommand extends Command
  constructor: ->
    self = this
    super ':new', ':n', (bucket, taskId, value) ->
      task = new Task
        description: value
        bucket: bucket
        createdAt: Date.now()

      task.save (err) ->
        if err
          Logger.alert err
        else
          self.notifyBucketUpdate bucket, taskId

class ChangeTaskCommand extends Command
  constructor: ->
    self = this
    super ':change', ':ch', (bucket, taskId, value) ->
      Task.findOneAndUpdate { _id: taskId }, { description: value, updatedAt: Date.now() }, (err, task) ->
        if err
          Logger.alert err
        else
          self.notifyBucketUpdate bucket, taskId

class CloseTaskCommand extends Command
  constructor: ->
    self = this
    super ':close', ':cl', 'check', 'ck', (bucket, taskId, value) ->
      Task.findOneAndUpdate { _id: taskId }, { bucket: 'done', updatedAt: Date.now() }, (err, task) ->
        if err
          Logger.alert err
        else
          self.notifyBucketUpdate bucket, taskId

class MoveTaskToBucketCommand extends Command
  constructor: ->
    self = this
    super ':moveTo', ':mt', (bucket, taskId, value) ->
      Task.findOne _id: taskId, (err, task) ->
        if err
          Logger.alert err
        else
          oldBucket = task.bucket
          if oldBucket isnt bucket
            task.update bucket: bucket, updatedAt: Date.now(), (err, task) ->
              if err
                Logger.alert err
              else
                self.notifyBucketUpdate oldBucket, taskId
                self.notifyBucketUpdate bucket, taskId

class EmptyBucketCommand extends Command
  constructor: ->
    self = this
    super ':empty!', ':trash!', (bucket, taskId, value) ->
      Task.update { bucket: bucket }, { bucket: 'trash', updatedAt: Date.now() }, { multi: true }, (err) ->
        if err
          Logger.alert err
        else
          self.notifyBucketUpdate bucket, taskId

class EmptyAllBucketsCommand extends Command
  constructor: ->
    self = this
    super ':emptyAll!', ':trashAll!', (bucket, taskId, value) ->
      Task.update { bucket: { $nin: ['done', 'trash'] } }, { bucket: 'trash', updatedAt: Date.now() }, { multi: true }, (err) ->
        if err
          Logger.alert err
        else
          self.notifyBucketUpdate 'today', null
          self.notifyBucketUpdate 'tomorrow', null
          self.notifyBucketUpdate 'twoDaysFromNow', null
          self.notifyBucketUpdate 'future', null

class DeleteTaskCommand extends Command
  constructor: ->
    self = this
    super ':delete', ':del', ':remove', ':rm', (bucket, taskId, value) ->
      Task.findOneAndUpdate { _id: taskId }, { bucket: 'trash' }, (err) ->
        if err
          Logger.alert err
        else
          self.notifyBucketUpdate bucket, taskId

class ShiftBucketCommand extends Command
  constructor: ->
    self = this
    super ':shift!', ':sh!', (bucket, taskId, value) ->
      switch bucket
        when 'tomorrow'
          self.shift 'tomorrow', 'today'
        when 'twoDaysFromNow'
          self.shift 'twoDaysFromNow', 'tomorrow'
        when 'future'
          self.shift 'future', 'twoDaysFromNow'

  shift: (from, to) ->
    self = this
    Task.update { bucket: from }, { bucket: to }, { multi: true }, (err) ->
      if err
        Logger.alert err
      else
        self.notifyBucketUpdate from, null
        self.notifyBucketUpdate to, null

class ShiftAllBucketsCommand extends Command
  constructor: ->
    super ':shiftAll!', ':sha!', (bucket, taskId, value) ->
      command = new ShiftBucketCommand()
      command.logic('tomorrow', taskId, value)
      command.logic('twoDaysFromNow', taskId, value)
      command.logic('future', taskId, value)

root = new RootCommand()
commands = [
  new NewTaskCommand(),
  new ChangeTaskCommand(),
  new CloseTaskCommand(),
  new MoveTaskToBucketCommand(),
  new EmptyBucketCommand(),
  new EmptyAllBucketsCommand(),
  new DeleteTaskCommand(),
  new ShiftBucketCommand(),
  new ShiftAllBucketsCommand()
]
root.link command for command in commands
exports.root = root
