#############################################################################################
# Views
#############################################################################################
window.App.CommandBoxView = Ember.View.extend
  templateName: 'command-box'
  elementId: 'command-box'
  classNameBindings: ['App.router.commandBoxController.visible']

  didInsertElement: ->
    $('form#command_form').submit (event)->
      event.preventDefault()
      App.router.get('commandBoxController').run()

#############################################################################################
# Controllers
#############################################################################################
window.App.CommandBoxController = Ember.Object.extend
  visible: false

  initialize: ->
    view = App.CommandBoxView.create()
    view.appendTo('body')

  show: ->
    @set 'visible', true
    Ember.run.next this, ->
      $('#command').focus()
      $('#command').val ":"

  hide: ->
    @set 'visible', false
    Ember.run.next this, ->
      $('#command').val ""
      $('#command').blur()

  runCommand: (command) ->
    if command
      $.post "/command/#{command.name}.json", args:command.args ? {} , (data) ->
        console.log 'run command:', command, data
        if data.status is 'success' and data.redirect
          window.location = "##{data.redirect}"

    @hide()

  run: ->
    @runCommand @getCommand()

  getCommand: ->
    rx = /(:[a-zA-Z_!]+)\s?(@[1-6])?\s?(.*)?/
    match = rx.exec $('#command').val()
    if match isnt null
      command =
        name: match[1]
        args:
          bucket: match[2]
          value: match[3]
          
      if App.router.get('applicationController').get("currentUser")
        command.args.bucket ?= "@#{App.router.get('bucketsController').get('selectedBucketIndex')+1}"
        command.args.taskId ?= App.router.get('tasksController').get('selectedTask')?._id

      return command

