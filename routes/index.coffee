Task = require("../models/task").Task
User = require("../models/user").User

exports.index = (req, res) ->
  res.render 'index'

exports.tasks = (req, res, next) ->
  userId = req.session.userId
  if userId
    Task.find(bucket: req.params['bucket'], _owner: userId).sort('createdAt').exec (err, tasks) ->
      if err
        next err
      else
        res.send
          status: 'success'
          bucket: req.params['bucket']
          tasks: tasks
   else
     res.send status: 'failure'

exports.command = (req, res, next) ->
  args = req.body.args || {}
  req.commandRequest =
    name: req.params.command
    value: args.value
    taskId: args.taskId

    bucket: do ->
      switch args.bucket
        when '@1' then 'today'
        when '@2' then 'tomorrow'
        when '@3' then 'twoDaysFromNow'
        when '@4' then 'future'
        else args.bucket

  unless req.session.userId
    next()
  else
    User.findById(req.session.userId).select('-salt -hash').exec (err, user) ->
      if err
        next err
      else
        req.commandRequest.user = user
        next()

exports.user = (req, res, next) ->
  userId = req.session.userId
  if userId
    User.findById(userId).select('-salt -hash').exec (err, user) ->
      if err
        next err
      else
        res.send user: user
  else
    res.send user: null

exports.login = (req, res, next) ->
  User.findOne username: req.body.username, (err, user) ->
    if err
      next err
    else
      if user
        pass = require 'pwd'
        pass.hash req.body.password, user.salt, (err, hash) ->
          if err
            next err
          else
            if user.hash is hash
              req.session.regenerate ->
                req.session.userId = user._id
                res.send status: 'success'
            else
              res.send status: 'failure'
      else
        res.send
          status: 'failure'
          error: 'user not found'

exports.register = (req, res, next) ->
  pass = require 'pwd'
  pass.hash req.body.password, (err, salt, hash) ->
    if err
      next err
    else
      user = new User
        username: req.body.username
        salt: salt
        hash: hash

      user.save (err) ->
        if err
          next err
        else
          req.session.regenerate ->
            req.session.userId = user._id
            res.send status: 'success'

exports.logout = (req, res) ->
  req.session.destroy ->
    res.redirect '/'

