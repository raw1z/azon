Task = require("./task").Task

class Command
  constructor: (name, aliases..., needsUser, logic) ->
    @name = name
    @aliases = aliases
    @logic = logic
    @needsUser = needsUser

  processHelp: (req) ->
    if req.commandRequest?.name in [':help', ':h', ':describe', ':desc']
      req.commandRequest.help ?= []
      unless req.commandRequest.value
        req.commandRequest.help.push usage: @usage(), desc: @desc(), needsUser: @needsUser
      else if req.commandRequest.value is @name
        req.commandRequest.help.push usage: @usage(), desc: @desc(), needsUser: @needsUser

  canRunCommand: (req) ->
    name = req.commandRequest?.name
    if (@name is name) or (@aliases.indexOf(name) isnt -1)
      if @needsUser then req.commandRequest.user? else yes
    else
      no

  middleware: ->
    self = this
    (req, res, next) ->
      self.processHelp(req)

      if self.canRunCommand(req)
        console.log req.commandRequest
        try
          self.logic(req, res, next)
        catch error
          res.send
            status: 'failure'
            error: 'exception raised'
            commandData: req.commandRequest
            errorData: error
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

  usage: ->
    ":new|:n [bucket] <description>"

  desc: ->
    "Create a new task. Unless the optional parameter [bucket] is given, the new task is created inside the currently selected bucket"

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

  usage: ->
    ":change|:ch <description>"

  desc: ->
    "Change the description of the currently selected task"

class CloseTaskCommand extends Command
  constructor: ->
    self = this
    super ':close', ':cl', ':check', ':ck', yes, (req, res, next) ->
      Task.findOneAndUpdate { _id: req.commandRequest.taskId }, { bucket: 'done', updatedAt: Date.now() }, (err, task) ->
        if err
          next err
        else
          self.notifyBucketUpdate req.commandRequest.bucket, req.commandRequest.taskId
          res.send status: 'success'

  usage: ->
    ":close|:cl|:check|:ck"

  desc: ->
    "Mark the current tasks as done. The task is then hidden from the bucket"

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

  usage: ->
    ":moveTo|:mt <bucket>"

  desc: ->
    "Move the currently selected task to the given bucket"

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

  usage: ->
    ":empty!|:trash! [bucket]"

  desc: ->
    "Delete all the tasks inside a bucket. unless the optional [bucket] parameter is given, this command runs on the currently selected bucket"

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

  usage: ->
    ":emptyAll!|:trashAll!"

  desc: ->
    "Apply the :delete command to all the buckets"

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

  usage: ->
    ":delete|:del|:remove|:rm"

  desc: ->
    "Delete the currently selected task"

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

  usage: ->
    ":shift!|:sh! [bucket]"

  desc: ->
    "Move all the tasks from a bucket to its immediate successor (@2 -> @1, @3 -@2, @4 -> @5). unless the optional [bucket] parameter is given, this command runs on the currently selected bucket"

class ShiftAllBucketsCommand extends Command
  constructor: ->
    super ':shiftAll!', ':sha!', yes, (req, res, next) ->
      ShiftCommand.shift.apply this, [req, res, next, 'tomorrow', 'today']
      ShiftCommand.shift.apply this, [req, res, next, 'twoDaysFromNow', 'tomorrow']
      ShiftCommand.shift.apply this, [req, res, next, 'future', 'twoDaysFromNow']
      res.send status: 'success'

  usage: ->
    ":shiftAll|:sha!"

  desc: ->
    "Apply the :shift command to all the buckets"

class LogoutCommand extends Command
  constructor: ->
    super ':logout!', ':signout!', yes, (req, res, next) ->
      req.session.destroy ->
        res.send
          status: 'success'
          redirect: '/'

  usage: ->
    ":logout!|:signout!"

  desc: ->
    "Close the current user session"

class LoginCommand extends Command
  constructor: ->
    super ':login', ':signin', no, (req, res, next) ->
      if req.commandRequest.user
        res.send
          status: 'failure'
          error: 'already logged in'
      else
        res.send
          status: 'success'
          redirect: '/login'

  usage: ->
    ":login|:signin"

  desc: ->
    "Redirect to the new user session form"

class RegisterCommand extends Command
  constructor: ->
    super ':register', ':signup', no, (req, res, next) ->
      if req.commandRequest.user
        res.send
          status: 'failure'
          error: 'already logged in'
      else
        res.send
          status: 'success'
          redirect: '/register'

  usage: ->
    ":register|:signup"

  desc: ->
    "Redirect to the new user registration form"

class HelpCommand extends Command
  constructor: ->
    super ':help', ':h', ':describe', ':desc', no, (req, res, next) ->
      res.send
        status: 'success'
        help: req.commandRequest.help

  usage: ->
    ":help|:h|:describe|:desc [command]"

  desc: ->
    "Display the help. if the optional [command] parameter is given then only the help available for it will be displayed"

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
    new ShiftAllBucketsCommand(),
    new LogoutCommand(),
    new LoginCommand(),
    new RegisterCommand()
  ]

  for command in commands
    app.use command.middleware()

  app.use new HelpCommand().middleware()
  app.use InvalidCommand.middleware()

