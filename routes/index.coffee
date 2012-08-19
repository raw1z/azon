Logger = require("../models/logger").Logger
Runner = require("../models/runner").Runner
Task = require("../models/task").Task

exports.index = (req, res) ->
  res.render 'index'

exports.tasks = (req, res) ->
  Task.find(bucket: req.params['bucket']).sort('createdAt').exec (err, tasks) ->
    if err
      Logger.alert err
    else
      global.io.sockets.emit 'tasks'
        bucket: req.params['bucket']
        tasks: tasks

  res.send
    status: 'success'

exports.command = (req, res) ->
  command = req.body['command']
  runner = new Runner()
  runner.run command.name, command.bucket, command.task, command.value
  res.send
    status: 'success'
    command: command

