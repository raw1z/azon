Logger = require('./logger').Logger
Task = require("./task").Task

class Command
  constructor: (name, aliases..., logic) ->
    @name = name
    @aliases = aliases
    @logic = logic

  supportCommand: (name) ->
    (@name is name) or (@aliases.indexOf(name) isnt -1)

  middleware: ->
    self = this
    (req, res, next) ->
      if req.commandRequest and self.supportCommand(req.commandRequest.name)
        self.logic(req, res, next)
      else
        next()

  notifyBucketUpdate: (name, updatedTask) ->
    global.io.sockets.emit 'update bucket', bucket: name, updatedTask: updatedTask

class RootCommand extends Command
  constructor: ->
    self = this
    super ':', (req, res, next) ->

class NewTaskCommand extends Command
  constructor: ->
    self = this
    super ':new', ':n', (req, res, next) ->
      task = new Task
        description: req.commandRequest.value
        bucket: req.commandRequest.bucket
        createdAt: Date.now()
        _owner: req.commandRequest.user._id

      task.save (err) ->
        if err
          next(err)
        else
          self.notifyBucketUpdate req.commandRequest.bucket, task._id

class ChangeTaskCommand extends Command
  constructor: ->
    self = this
    super ':change', ':ch', (req, res, next) ->
      Task.findOneAndUpdate { _id: req.commandRequest.taskId }, { description: req.commandRequest.value, updatedAt: Date.now() }, (err, task) ->
        if err
          next(err)
        else
          self.notifyBucketUpdate req.commandRequest.bucket, req.commandRequest.taskId

class CloseTaskCommand extends Command
  constructor: ->
    self = this
    super ':close', ':cl', 'check', 'ck', (req, res, next) ->
      Task.findOneAndUpdate { _id: req.commandRequest.taskId }, { bucket: 'done', updatedAt: Date.now() }, (err, task) ->
        if err
          next(err)
        else
          self.notifyBucketUpdate req.commandRequest.bucket, req.commandRequest.taskId

class MoveTaskToBucketCommand extends Command
  constructor: ->
    self = this
    super ':moveTo', ':mt', (req, res, next) ->
      Task.findOne _id: req.commandRequest.taskId, (err, task) ->
        if err
          next(err)
        else
          oldBucket = task.bucket
          if oldBucket isnt req.commandRequest.bucket
            task.update bucket: req.commandRequest.bucket, updatedAt: Date.now(), (err, task) ->
              if err
                next(err)
              else
                self.notifyBucketUpdate oldBucket, req.commandRequest.taskId
                self.notifyBucketUpdate req.commandRequest.bucket, req.commandRequest.taskId

class EmptyBucketCommand extends Command
  constructor: ->
    self = this
    super ':empty!', ':trash!', (req, res, next) ->
      Task.update { bucket: req.commandRequest.bucket, _owner: req.commandRequest.user._id }, { bucket: 'trash', updatedAt: Date.now() }, { multi: true }, (err) ->
        if err
          next(err)
        else
          self.notifyBucketUpdate req.commandRequest.bucket, req.commandRequest.taskId

class EmptyAllBucketsCommand extends Command
  constructor: ->
    self = this
    super ':emptyAll!', ':trashAll!', (req, res, next) ->
      Task.update { bucket: { $nin: ['done', 'trash'] }, _owner: req.commandRequest.user._id }, { bucket: 'trash', updatedAt: Date.now() }, { multi: true }, (err) ->
        if err
          next(err)
        else
          self.notifyBucketUpdate 'today', null
          self.notifyBucketUpdate 'tomorrow', null
          self.notifyBucketUpdate 'twoDaysFromNow', null
          self.notifyBucketUpdate 'future', null

class DeleteTaskCommand extends Command
  constructor: ->
    self = this
    super ':delete', ':del', ':remove', ':rm', (req, res, next) ->
      Task.findOneAndUpdate { _id: req.commandRequest.taskId }, { bucket: 'trash', updatedAt: Date.now() }, (err) ->
        if err
          next(err)
        else
          self.notifyBucketUpdate req.commandRequest.bucket, req.commandRequest.taskId

class ShiftBucketCommand extends Command
  constructor: ->
    self = this
    super ':shift!', ':sh!', (req, res, next) ->
      self.env = env
      switch req.commandRequest.bucket
        when 'tomorrow'
          self.shift 'tomorrow', 'today'
        when 'twoDaysFromNow'
          self.shift 'twoDaysFromNow', 'tomorrow'
        when 'future'
          self.shift 'future', 'twoDaysFromNow'

  shift: (from, to) ->
    self = this
    Task.update { bucket: from, _owner: self.req.commandRequest.user._id }, { bucket: to, updatedAt: Date.now() }, { multi: true }, (err) ->
      if err
        next(err)
      else
        self.notifyBucketUpdate from, null
        self.notifyBucketUpdate to, null

class ShiftAllBucketsCommand extends Command
  constructor: ->
    super ':shiftAll!', ':sha!', (req, res, next) ->
      command = new ShiftBucketCommand()

      command.middleware
        user: req.commandRequest.user
        command:
          bucket: 'tomorrow'
          taskId: req.commandRequest.taskId
          value: req.commandRequest.value

      command.middleware
        user: req.commandRequest.user
        command:
          bucket: 'twoDaysFromNow'
          taskId: req.commandRequest.taskId
          value: req.commandRequest.value

      command.middleware
        user: req.commandRequest.user
        command:
          bucket: 'future'
          taskId: req.commandRequest.taskId
          value: req.commandRequest.value

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

exports.configure = (app) ->
  app.param 'command', (req, res, next, command) ->
    req.commandRequest =
      name: command
      taskId: req.body.args.taskId

      buket: do ->
        switch req.body.args.bucket
          when '@1' then 'today'
          when '@2' then 'tomorrow'
          when '@3' then 'twoDaysFromNow'
          when '@4' then 'future'
          when '@5' then 'done'
          when '@6' then 'trash'
          else name

    unless req.session.user
      next()
    else
      User.findById req.session.user, (err, user) ->
        req.commandRequest.user = user unless err
        next()

  for command in commands
    app.use command.middleware()

