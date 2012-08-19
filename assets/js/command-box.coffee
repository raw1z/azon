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
      $('#command').val ":"
      $('#command').focus()

  hide: ->
    @set 'visible', false
    Ember.run.next this, ->
      $('#command').val ""
      $('#command').blur()

  run: ->
    command = @getCommand()
    if command
      $.post '/command.json', command: @getCommand(), (data) ->
        console.log data
    @hide()

  getCommand: ->
    rx = /(:[a-zA-Z_!]+)\s?(@[1-6])?\s?(.*)?/
    match = rx.exec $('#command').val()
    if match isnt null
      {
        name: match[1],
        bucket: match[2] ? "@#{App.router.get('bucketsController').get('selectedBucketIndex')+1}",
        task: App.router.get('tasksController').get('selectedTask')?._id,
        value: match[3]
      }
