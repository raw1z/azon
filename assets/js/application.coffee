#= require jquery
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
          console.log "down"
        when 75 # k
          console.log "up"
        when 72 # h
          App.bucketsController.selectPrevious()
        when 76 # l
          App.bucketsController.selectNext()
        when 191 # :
          App.commandBoxController.show()

window.configureWebsocket = ->
  socket = io.connect('http://localhost')
  socket.on 'connect', ->
    console.log "Connected to server"
    App.bucketsController.fetchTasks()

  socket.on 'tasks', (data) ->
    App.bucketsController.populateBucket(data.bucket, data.tasks)

  socket.on 'update bucket', (bucketId) ->
    App.bucketsController.fetchBucketTasks(bucketId)

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
  classNames: ['task']
  labelBinding: 'content.description'
  showCheckbox: (->
    @.get('content').get('bucket') is 'today'
  ).property('content')

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

  selectedBucket: (->
    @content.find (item) ->
      item.selected is true
  ).property('content').volatile()

  selectedIndex: (->
    @content.indexOf @get('selectedBucket')
  ).property('selectedBucket').volatile()

  selectPrevious: ->
    bucket = @get('selectedBucket')
    selectedIndex = @content.indexOf bucket

    if selectedIndex > 0
      bucket.set 'selected', false
      @content.objectAt(selectedIndex-1).set "selected", true

  selectNext: ->
    bucket = @get('selectedBucket')
    selectedIndex = @content.indexOf bucket

    if selectedIndex < @content.length - 1
      bucket.set 'selected', false
      @content.objectAt(selectedIndex+1).set "selected", true

window.App.CommandBoxController = Ember.Object.extend
  visible: false
  view: null

  initialize: ->
    view = App.CommandBoxView.create()
    @set 'view', view
    view.appendTo('body')

  show: ->
    @set 'visible', true
    $('#command').val ""
    $('#command').focus()

  hide: ->
    @set 'visible', false
    $('#command').val ""
    $('#command').blur()

  run: ->
    $.post '/command.json', command: @getCommand(), (data) ->
      console.log data
    @hide()

  getCommand: ->
    rx = /(:[a-zA-Z_]+)\s?(@[1-4])?\s?(.*)?/
    match = rx.exec $('#command').val()
    return {
      name: match[1],
      target: match[2] ? "@#{App.bucketsController.get('selectedIndex')+1}",
      value: match[3]
    }

