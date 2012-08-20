Task = require("./task").Task

class Command
  constructor: (name, aliases..., needsUser, logic) ->
    @name = name
    @aliases = aliases
    @logic = logic
    @needsUser = needsUser

  canRunCommand: (req) ->
    name = req.commandRequest.name
    if (@name is name) or (@aliases.indexOf(name) isnt -1)
      if @needsUser then req.commandRequest.user? else yes
    else
      no

  middleware: ->
    self = this
    (req, res, next) ->
      if req.commandRequest and self.canRunCommand(req)
        console.log req.commandRequest
        self.logic(req, res, next)
      else
        next()

  notifyBucketUpdate: (name, updatedTask) ->
    global.io.sockets.emit 'update bucket', bucket: name, updatedTask: updatedTask

class InvalidCommand
  @middleware: ->
    (req, res, next) ->
      if req.commandRequest
        res.send
          status: 'failure'
          error: 'unknown command'
      else
        next()

class NewTaskCommand extends Command
  constructor: ->
    self = this
    super ':new', ':n', yes, (req, res, next) ->
      task = new Task
        description: req.commandRequest.value
        bucket: req.commandRequest.bucket
        createdAt: Date.now()
        _owner: req.commandRequest.user._id

      task.save (err) ->
        if err
          next err
        else
          self.notifyBucketUpdate req.commandRequest.bucket, task._id
          res.send status: 'success'

class ChangeTaskCommand extends Command
  constructor: ->
    self = this
    super ':change', ':ch', yes, (req, res, next) ->
      Task.findOneAndUpdate { _id: req.commandRequest.taskId }, { description: req.commandRequest.value, updatedAt: Date.now() }, (err, task) ->
        if err
          next err
        else
          self.notifyBucketUpdate req.commandRequest.bucket, req.commandRequest.taskId
          res.send status: 'success'

class CloseTaskCommand extends Command
  constructor: ->
    self = this
    super ':close', ':cl', 'check', 'ck', yes, (req, res, next) ->
      Task.findOneAndUpdate { _id: req.commandRequest.taskId }, { bucket: 'done', updatedAt: Date.now() }, (err, task) ->
        if err
          next err
        else
          self.notifyBucketUpdate req.commandRequest.bucket, req.commandRequest.taskId
          res.send status: 'success'

class MoveTaskToBucketCommand extends Command
  constructor: ->
    self = this
    super ':moveTo', ':mt', yes, (req, res, next) ->
      Task.findOne _id: req.commandRequest.taskId, (err, task) ->
        if err
          next err
        else
          oldBucket = task.bucket
          if oldBucket isnt req.commandRequest.bucket
            task.update bucket: req.commandRequest.bucket, updatedAt: Date.now(), (err, task) ->
              if err
                next err
              else
                self.notifyBucketUpdate oldBucket, req.commandRequest.taskId
                self.notifyBucketUpdate req.commandRequest.bucket, req.commandRequest.taskId
                res.send status: 'success'

class EmptyBucketCommand extends Command
  constructor: ->
    self = this
    super ':empty!', ':trash!', yes, (req, res, next) ->
      Task.update { bucket: req.commandRequest.bucket, _owner: req.commandRequest.user._id }, { bucket: 'trash', updatedAt: Date.now() }, { multi: true }, (err) ->
        if err
          next err
        else
          self.notifyBucketUpdate req.commandRequest.bucket, req.commandRequest.taskId
          res.send status: 'success'

class EmptyAllBucketsCommand extends Command
  constructor: ->
    self = this
    super ':emptyAll!', ':trashAll!', yes, (req, res, next) ->
      Task.update { bucket: { $nin: ['done', 'trash'] }, _owner: req.commandRequest.user._id }, { bucket: 'trash', updatedAt: Date.now() }, { multi: true }, (err) ->
        if err
          next err
        else
          self.notifyBucketUpdate 'today', null
          self.notifyBucketUpdate 'tomorrow', null
          self.notifyBucketUpdate 'twoDaysFromNow', null
          self.notifyBucketUpdate 'future', null
          res.send status: 'success'

class DeleteTaskCommand extends Command
  constructor: ->
    self = this
    super ':delete', ':del', ':remove', ':rm', yes, (req, res, next) ->
      Task.findOneAndUpdate { _id: req.commandRequest.taskId }, { bucket: 'trash', updatedAt: Date.now() }, (err) ->
        if err
          next err
        else
          self.notifyBucketUpdate req.commandRequest.bucket, req.commandRequest.taskId
          res.send status: 'success'

class ShiftCommand
  @shift: (req, res, next, from, to) ->
    console.log next
    self = this
    Task.update { bucket: from, _owner: req.commandRequest.user._id }, { bucket: to, updatedAt: Date.now() }, { multi: true }, (err) ->
      if err
        next err
      else
        self.notifyBucketUpdate from, null
        self.notifyBucketUpdate to, null

class ShiftBucketCommand extends Command
  constructor: ->
    self = this
    super ':shift!', ':sh!', yes, (req, res, next) ->
      switch req.commandRequest.bucket
        when 'tomorrow'
          ShiftCommand.shift.apply this, [req, res, next, 'tomorrow', 'today']
        when 'twoDaysFromNow'
          ShiftCommand.shift.apply this, [req, res, next, 'twoDaysFromNow', 'tomorrow']
        when 'future'
          ShiftCommand.shift.apply this, [req, res, next, 'future', 'twoDaysFromNow']

      res.send status: 'success'

class ShiftAllBucketsCommand extends Command
  constructor: ->
    super ':shiftAll!', ':sha!', yes, (req, res, next) ->
      ShiftCommand.shift.apply this, [req, res, next, 'tomorrow', 'today']
      ShiftCommand.shift.apply this, [req, res, next, 'twoDaysFromNow', 'tomorrow']
      ShiftCommand.shift.apply this, [req, res, next, 'future', 'twoDaysFromNow']
      res.send status: 'success'

exports.watch = (app) ->
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

  for command in commands
    app.use command.middleware()

  app.use InvalidCommand.middleware()

