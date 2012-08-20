Logger = require("../models/logger").Logger
Runner = require("../models/runner").Runner
Task = require("../models/task").Task
User = require("../models/user").User

exports.index = (req, res) ->
  res.render 'index'

exports.tasks = (req, res) ->
  userId = req.session.userId
  if userId
    Task.find(bucket: req.params['bucket'], _owner: userId).sort('createdAt').exec (err, tasks) ->
      if err
        Logger.alert err
      else
        res.send
          status: 'success'
          bucket: req.params['bucket']
          tasks: tasks
   else
     res.send status: 'failure'

exports.command = (req, res) ->
  userId = req.session.userId
  if userId
    User.findById userId, (err, user) ->
      if err
        Logger.alert err
      else
        command = req.body['command']
        runner = new Runner
        runner.run
          user: user
          command:
            name: command.name
            bucket: command.bucket
            taskId: command.task
            value: command.value

        res.send
          status: 'success'
          command: command
   else
     res.send status: 'failure'

exports.user = (req, res) ->
  userId = req.session.userId
  if userId
    User.findById(userId).select('-salt -hash').exec (err, user) ->
      if err
        Logger.alert err
      else
        res.send user: user
  else
    res.send user: null

exports.login = (req, res) ->
  User.findOne username: req.body.username, (err, user) ->
    pass = require 'pwd'
    pass.hash req.body.password, user.salt, (err, hash) ->
      if user.hash is hash
        req.session.regenerate ->
          req.session.userId = user._id
          res.send status: 'success'
      else
        res.send status: 'failure'

exports.register = (req, res) ->
  pass = require 'pwd'
  pass.hash req.body.password, (err, salt, hash) ->
    if err
      Logger.alert err
    else
      user = new User
        username: req.body.username
        salt: salt
        hash: hash

      user.save (err) ->
        if err
          Logger.alert err
        else
          req.session.regenerate ->
            req.session.userId = user._id
            res.send status: 'success'

exports.logout = (req, res) ->
  req.session.destroy ->
    res.redirect '/'

