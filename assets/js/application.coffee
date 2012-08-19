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
          App.tasksController.selectNextTask()
        when 75 # k
          App.tasksController.selectPreviousTask()
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
    App.tasksController.fetchTasks()

  socket.on 'tasks', (data) ->
    App.bucketsController.populateBucket(data.bucket, data.tasks)

  socket.on 'update bucket', (data) ->
    App.tasksController.fetchBucketTasks(data.bucket)

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

    App.tasksController = App.TasksController.create()

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

window.App.Task = Ember.Object.extend
  description: null
  bucket: null
  selected: false
  id: (->
    @_id
  ).property()

#############################################################################################
# Views
#############################################################################################
window.App.BucketView = Ember.View.extend
  templateName: 'bucket'
  tagName: 'section'
  classNameBindings: ['label', 'spanWidth', 'content.selected']
  label: 'bucket'
  spanWidth: (() -> "span#{12/App.bucketsController.content.length}").property()
  titleBinding: 'content.name'

window.App.BucketCollectionView = Ember.CollectionView.extend
  classNames: ['row-fluid']
  itemViewClass: App.BucketView
  elementId: 'buckets'

window.App.CommandBoxView = Ember.View.extend
  templateName: 'command-box'
  elementId: 'command-box'
  classNameBindings: ['App.commandBoxController.visible']

  didInsertElement: ->
    $('form#command_form').submit (event)->
      event.preventDefault()
      App.commandBoxController.run()

window.App.TaskView = Ember.View.extend
  templateName: 'task'
  classNameBindings: ['task', 'content.selected']
  task: 'task'
  labelBinding: 'content.description'
  elementId: (->
    @content.get 'id'
  ).property()

#############################################################################################
# Controllers
#############################################################################################
window.App.BucketsController = Ember.ArrayController.extend
  content: []
  selectedBucketIndex: 0

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

  populateBucket: (bucketId, tasks) ->
    for bucket in @content when bucket.id == bucketId
      bucket.set 'tasks', []
      for object in tasks
        bucket.tasks.pushObject App.Task.create(object)

      selectedIndex = App.tasksController.get 'selectedTaskIndex'
      bucket.tasks[selectedIndex]?.set 'selected', true

  selectedBucket: (->
    @content.objectAt @selectedBucketIndex
  ).property().volatile()

  selectPreviousBucket: ->
    if @selectedBucketIndex > 0
      @content.objectAt(@selectedBucketIndex).set "selected", false
      @content.objectAt(@selectedBucketIndex-1).set "selected", true
      @selectedBucketIndex--
      App.tasksController.updateSelection()

  selectNextBucket: ->
    if @selectedBucketIndex < @content.length - 1
      @content.objectAt(@selectedBucketIndex).set "selected", false
      @content.objectAt(@selectedBucketIndex+1).set "selected", true
      @selectedBucketIndex++
      App.tasksController.updateSelection()

window.App.TasksController = Ember.Object.extend
  scheduledHiglight: null
  selectedTaskIndexes:
    today: 0
    tomorrow: 0
    twoDaysFromNow: 0
    future: 0

  fetchBucketTasks: (bucket) ->
    id = if typeof bucket is "string"
      bucket
    else
      bucket.id
    $.get "/buckets/#{id}/tasks.json"

  fetchTasks: ->
    for bucket in App.bucketsController.content
      @fetchBucketTasks(bucket)

  selectedTaskIndex: (->
    bucket = App.bucketsController.get 'selectedBucket'

    if @selectedTaskIndexes[bucket.id] >= bucket.tasks.length
      @selectedTaskIndexes[bucket.id] = bucket.tasks.length - 1

    if @selectedTaskIndexes[bucket.id] < 0
      @selectedTaskIndexes[bucket.id] = 0

    @selectedTaskIndexes[bucket.id]
  ).property().volatile()

  selectedTask: (->
    bucket = App.bucketsController.get 'selectedBucket'
    bucket.tasks.objectAt @get('selectedTaskIndex')
  ).property().volatile()

  selectPreviousTask: ->
    bucket = App.bucketsController.get 'selectedBucket'
    selectedIndex = @get 'selectedTaskIndex'
    if selectedIndex > 0
      bucket.tasks.objectAt(selectedIndex).set 'selected', false
      @selectedTaskIndexes[bucket.id]--
      @updateSelection()

  selectNextTask: ->
    bucket = App.bucketsController.get 'selectedBucket'
    selectedIndex = @get 'selectedTaskIndex'
    if selectedIndex < bucket.tasks.length - 1
      bucket.tasks.objectAt(selectedIndex).set 'selected', false
      @selectedTaskIndexes[bucket.id]++
      @updateSelection()

  updateSelection: ->
    bucket = App.bucketsController.get 'selectedBucket'
    for task in bucket.tasks
      task.set 'selected', false

    task = @get 'selectedTask'
    if task
      task.set 'selected', true
      @ensureVisible task

  ensureVisible: (task) ->
    docViewTop = $(window).scrollTop()
    docViewBottom = docViewTop + $(window).height()

    elem = "##{task.get('id')}"
    elemTop = $(elem).offset().top
    elemBottom = elemTop + $(elem).height()

    isVisible = ((elemBottom >= docViewTop) and
    (elemTop <= docViewBottom) and
    (elemBottom <= docViewBottom) and
    (elemTop >= docViewTop))
     
    unless isVisible
      position = $(elem).offset().top - 30
      $('html, body').animate scrollTop: position, '400'

    # ensure that the logo and the buckets headers are visible when 
    # we are at the top of a bucket
    selectedBucket = App.bucketsController.get 'selectedBucket'
    taskIndex = selectedBucket.tasks.indexOf task
    if taskIndex is 0
      $('html, body').animate scrollTop: 0, '100'


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
        bucket: match[2] ? "@#{App.bucketsController.get('selectedBucketIndex')+1}",
        task: App.tasksController.get('selectedTask')?._id,
        value: match[3]
      }

