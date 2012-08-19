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

  run: (env) ->
    if (@name is env.command.name) or (@aliases.indexOf(env.command.name) isnt -1)
      env.command.bucket = @getBucket(env.command.bucket)
      @logic(env)
    else
      @next?.run(env)

  notifyBucketUpdate: (name, updatedTask) ->
    global.io.sockets.emit 'update bucket', bucket: name, updatedTask: updatedTask

class RootCommand extends Command
  constructor: ->
    self = this
    super ':', (env) ->

class NewTaskCommand extends Command
  constructor: ->
    self = this
    super ':new', ':n', (env) ->
      task = new Task
        description: env.command.value
        bucket: env.command.bucket
        createdAt: Date.now()
        _owner: env.user._id

      task.save (err) ->
        if err
          Logger.alert err
        else
          self.notifyBucketUpdate env.command.bucket, task._id

class ChangeTaskCommand extends Command
  constructor: ->
    self = this
    super ':change', ':ch', (env) ->
      Task.findOneAndUpdate { _id: env.command.taskId }, { description: env.command.value, updatedAt: Date.now() }, (err, task) ->
        if err
          Logger.alert err
        else
          self.notifyBucketUpdate env.command.bucket, env.command.taskId

class CloseTaskCommand extends Command
  constructor: ->
    self = this
    super ':close', ':cl', 'check', 'ck', (env) ->
      Task.findOneAndUpdate { _id: env.command.taskId }, { bucket: 'done', updatedAt: Date.now() }, (err, task) ->
        if err
          Logger.alert err
        else
          self.notifyBucketUpdate env.command.bucket, env.command.taskId

class MoveTaskToBucketCommand extends Command
  constructor: ->
    self = this
    super ':moveTo', ':mt', (env) ->
      Task.findOne _id: env.command.taskId, (err, task) ->
        if err
          Logger.alert err
        else
          oldBucket = task.bucket
          if oldBucket isnt env.command.bucket
            task.update bucket: env.command.bucket, updatedAt: Date.now(), (err, task) ->
              if err
                Logger.alert err
              else
                self.notifyBucketUpdate oldBucket, env.command.taskId
                self.notifyBucketUpdate env.command.bucket, env.command.taskId

class EmptyBucketCommand extends Command
  constructor: ->
    self = this
    super ':empty!', ':trash!', (env) ->
      Task.update { bucket: env.command.bucket, _owner: env.user._id }, { bucket: 'trash', updatedAt: Date.now() }, { multi: true }, (err) ->
        if err
          Logger.alert err
        else
          self.notifyBucketUpdate env.command.bucket, env.command.taskId

class EmptyAllBucketsCommand extends Command
  constructor: ->
    self = this
    super ':emptyAll!', ':trashAll!', (env) ->
      Task.update { bucket: { $nin: ['done', 'trash'] }, _owner: env.user._id }, { bucket: 'trash', updatedAt: Date.now() }, { multi: true }, (err) ->
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
    super ':delete', ':del', ':remove', ':rm', (env) ->
      Task.findOneAndUpdate { _id: env.command.taskId }, { bucket: 'trash', updatedAt: Date.now() }, (err) ->
        if err
          Logger.alert err
        else
          self.notifyBucketUpdate env.command.bucket, env.command.taskId

class ShiftBucketCommand extends Command
  constructor: ->
    self = this
    super ':shift!', ':sh!', (env) ->
      self.env = env
      switch env.command.bucket
        when 'tomorrow'
          self.shift 'tomorrow', 'today'
        when 'twoDaysFromNow'
          self.shift 'twoDaysFromNow', 'tomorrow'
        when 'future'
          self.shift 'future', 'twoDaysFromNow'

  shift: (from, to) ->
    self = this
    Task.update { bucket: from, _owner: self.env.user._id }, { bucket: to, updatedAt: Date.now() }, { multi: true }, (err) ->
      if err
        Logger.alert err
      else
        self.notifyBucketUpdate from, null
        self.notifyBucketUpdate to, null

class ShiftAllBucketsCommand extends Command
  constructor: ->
    super ':shiftAll!', ':sha!', (env) ->
      command = new ShiftBucketCommand()

      command.logic
        user: env.user
        command:
          bucket: 'tomorrow'
          taskId: env.command.taskId
          value: env.command.value

      command.logic
        user: env.user
        command:
          bucket: 'twoDaysFromNow'
          taskId: env.command.taskId
          value: env.command.value

      command.logic
        user: env.user
        command:
          bucket: 'future'
          taskId: env.command.taskId
          value: env.command.value

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
