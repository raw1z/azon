#= require jquery
#= require jquery-ui
#= require jquery.form
#= require handlebars-1.0.0.beta.6
#= require ember
#= require bootstrap.min

#############################################################################################
# utility functions
#############################################################################################
setupShorcuts = ->
  $(document).keydown (e) ->
    if $(document.activeElement)[0] is $(document.body)[0]
      switch e.keyCode
        when 74 # j
          App.bucketsController.selectNextTask()
        when 75 # k
          App.bucketsController.selectPreviousTask()
        when 72 # h
          App.bucketsController.selectPreviousBucket()
        when 76 # l
          App.bucketsController.selectNextBucket()
        when 191,186 # :
          App.commandBoxController.show()
        else
          console.log e.keyCode

window.configureWebsocket = ->
  socket = io.connect('http://localhost')
  socket.on 'connect', ->
    console.log "Connected to server"
    App.bucketsController.fetchTasks()

  socket.on 'tasks', (data) ->
    App.bucketsController.populateBucket(data.bucket, data.tasks)

  socket.on 'update bucket', (bucketId) ->
    App.bucketsController.fetchBucketTasks(bucketId)

  socket.on 'log info', (data) ->
    console.log data

  socket.on 'log erro', (data) ->
    console.log data

#############################################################################################
# Application
#############################################################################################
window.App = Ember.Application.create
  ready: ->
    App.bucketsController = App.BucketsController.create()
    App.bucketsController.initialize()

    App.commandBoxController = App.CommandBoxController.create()
    App.commandBoxController.initialize()

    configureWebsocket()
    setupShorcuts()

    console.log "Application started"

#############################################################################################
# Models
#############################################################################################
window.App.Bucket = Ember.Object.extend
  id: null
  name: null
  position: 0
  selected: false
  tasks: []

  selectedTask: (->
    @tasks.find (item) ->
      item.selected is true
  ).property().volatile()

  selectedTaskIndex: (->
    @tasks.indexOf @get('selectedTask')
  ).property().volatile()

window.App.Task = Ember.Object.extend
  description: null
  bucket: null
  selected: false

#############################################################################################
# Views
#############################################################################################
window.App.BucketView = Ember.View.extend
  templateName: 'bucket'
  tagName: 'section'
  classNameBindings: ['label', 'spanWidth', 'selected']
  label: 'bucket'
  spanWidth: (() -> "span#{12/App.bucketsController.content.length}").property()
  titleBinding: 'content.name'
  selectedBinding: 'content.selected'

window.App.BucketCollectionView = Ember.CollectionView.extend
  classNames: ['row-fluid']
  itemViewClass: App.BucketView
  elementId: 'buckets'

window.App.CommandBoxView = Ember.View.extend
  templateName: 'command-box'
  elementId: 'command-box'
  classNameBindings: ['visible']
  visibleBinding: 'App.commandBoxController.visible'

  didInsertElement: ->
    $('form#command_form').submit (event)->
      event.preventDefault()
      App.commandBoxController.run()

window.App.TaskView = Ember.View.extend
  templateName: 'task'
  classNameBindings: ['task', 'selected']
  task: 'task'
  labelBinding: 'content.description'
  selectedBinding: 'content.selected'

#############################################################################################
# Controllers
#############################################################################################
window.App.BucketsController = Ember.ArrayController.extend
  content: []

  initialize: ->
    @createBuckets()

  createBuckets: ->
    buckets = {today: 'Today', tomorrow: 'Tomorrow', twoDaysFromNow: 'Two days from now', future: 'Future'}
    for id, name of buckets
      bucket = App.Bucket.create
        id: id
        name: name
      @content.pushObject bucket
    @content[0].set 'selected', true

  fetchBucketTasks: (bucket) ->
    id = if typeof bucket is "string"
      bucket
    else
      bucket.id
    $.get "/buckets/#{id}/tasks.json"

  fetchTasks: ->
    for bucket in @content
      @fetchBucketTasks(bucket)

  populateBucket: (bucketId, tasks) ->
    for bucket in @content when bucket.id == bucketId
      bucket.set 'tasks', []
      for object in tasks
        bucket.tasks.pushObject App.Task.create(object)
      bucket.tasks[0].set 'selected', true

  selectedBucket: (->
    @content.find (item) ->
      item.selected is true
  ).property('content').volatile()

  selectedBucketIndex: (->
    @content.indexOf @get('selectedBucket')
  ).property('selectedBucket').volatile()

  selectPreviousBucket: ->
    selectedIndex = @get 'selectedBucketIndex'
    if selectedIndex > 0
      @content.objectAt(selectedIndex).set "selected", false
      @content.objectAt(selectedIndex-1).set "selected", true

  selectNextBucket: ->
    selectedIndex = @get 'selectedBucketIndex'
    if selectedIndex < @content.length - 1
      @content.objectAt(selectedIndex).set "selected", false
      @content.objectAt(selectedIndex+1).set "selected", true

  selectPreviousTask: ->
    bucket = @get 'selectedBucket'
    selectedIndex = bucket.get 'selectedTaskIndex'
    if selectedIndex > 0
      bucket.tasks.objectAt(selectedIndex).set 'selected', false
      bucket.tasks.objectAt(selectedIndex-1).set 'selected', true

  selectNextTask: ->
    bucket = @get 'selectedBucket'
    selectedIndex = bucket.get 'selectedTaskIndex'
    if selectedIndex < bucket.tasks.length - 1
      bucket.tasks.objectAt(selectedIndex).set 'selected', false
      bucket.tasks.objectAt(selectedIndex+1).set 'selected', true

window.App.CommandBoxController = Ember.Object.extend
  visible: false
  view: null

  initialize: ->
    view = App.CommandBoxView.create()
    @set 'view', view
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
    console.log command
    if command isnt null
      $.post '/command.json', command: @getCommand(), (data) ->
        console.log data
    @hide()

  getCommand: ->
    rx = /(:[a-zA-Z_]+)\s?(@[1-4])?\s?(.*)?/
    match = rx.exec $('#command').val()
    if match isnt null
      {
        name: match[1],
        bucket: match[2] ? "@#{App.bucketsController.get('selectedBucketIndex')+1}",
        task: App.bucketsController.get('selectedBucket').get('selectedTask')._id,
        value: match[3]
      }

