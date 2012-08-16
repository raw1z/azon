Task = require("../models/task").Task

exports.index = (req, res) ->
  res.render 'index'

exports.tasks = (req, res) ->
  Task.find bucket: req.params['bucket'], (err, tasks) ->
    if err
      console.log err
    else
      global.io.sockets.emit 'tasks'
        bucket: req.params['bucket']
        tasks: tasks

  res.send
    status: 'success'

exports.command = (req, res) ->
  command = req.body['command']

  if command.name == ':new'
    bucket = switch command.target
      when '@1' then 'today'
      when '@2' then 'tomorrow'
      when '@3' then 'twoDaysFromNow'
      when '@4' then 'future'

    task = new Task
      description: command.value
      bucket: bucket
      createdAt: Date.now()

    task.save (err) ->
      if err
        console.log err
      else
        global.io.sockets.emit 'update bucket', bucket

  res.send
    status: 'success'
    command: command

