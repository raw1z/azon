#############################################################################################
# Models
#############################################################################################
App.Command = Ember.Object.extend
  name: null
  args: {}

App.Command.reopenClass
  parse: (str) ->
    command = null
    rx = /(:[a-zA-Z_!]+)\s?(@[1-4])?\s?(.*)?/
    match = rx.exec str
    if match isnt null
      command = App.Command.create
        input: str
        name: match[1]
        args:
          bucket: do ->
            return match[2] if match[2]?
            if App.router.get('applicationController').get("currentUser")
              return "@#{App.router.get('bucketsController').get('selectedBucketIndex')+1}"
            else
              return null

          taskId: do ->
            if App.router.get('applicationController').get("currentUser")
              return App.router.get('tasksController').get('selectedTask')?._id
            else
              return null

          value: match[3]

    return command

#############################################################################################
# Views
#############################################################################################
App.CommandBoxView = Ember.View.extend
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
App.CommandBoxController = Ember.Object.extend
  visible: false

  initialize: ->
    view = App.CommandBoxView.create()
    view.appendTo('body')
    @history = []

  show: (input=':') ->
    @set 'visible', true
    Ember.run.next this, ->
      $('#command').focus()
      App.router.get('commandHistoryController').reset(input)

  hide: ->
    @set 'visible', false
    Ember.run.next this, ->
      $('#command_form').each -> @reset()
      $('#command').blur()

  runCommand: (command, callback) ->
    @hide()
    if command
      $.post "/command/#{command.name}.json", args:command.args ? {} , (data) ->
        callback?(command, data)

  appendToHistory: (command) ->
    App.router.get('commandHistoryController').append command

  run: ->
    self = this
    @runCommand App.Command.parse($('#command').val()), (command, responseData) ->
      console.log 'command run:', command, responseData
      self.appendToHistory command

      if responseData.status is 'success' and responseData.redirect
        window.location = "##{responseData.redirect}"

App.CommandHistoryController = Ember.ArrayController.extend
  content: []
  last: 0
  currentInput: null

  append: (command) ->
    if @content.length is 0
      @content.pushObject command
    else
      unless @content[@content.length-1].input is command.input
        @content.pushObject command
    @reset()
 
  reset: (input=':') ->
    @last = @content.length
    @set 'currentInput', input

  up: ->
    @last-- if @last > 0
    @set 'currentInput', @content.objectAt(@last).input

  down: ->
    @last++ if @last < @content.length - 1
    @set 'currentInput', @content.objectAt(@last).input

