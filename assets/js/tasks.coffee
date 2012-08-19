#############################################################################################
# Model
#############################################################################################
window.App.Task = Ember.Object.extend
  description: null
  bucket: null
  selected: false
  id: (->
    @_id
  ).property()

#############################################################################################
# View
#############################################################################################
window.App.TaskView = Ember.View.extend
  templateName: 'task'
  classNameBindings: ['task', 'content.selected']
  task: 'task'
  labelBinding: 'content.description'
  elementId: (->
    @content.get 'id'
  ).property()

#############################################################################################
# Controller
#############################################################################################
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
    for bucket in App.router.get('bucketsController').content
      @fetchBucketTasks(bucket)

  selectedTaskIndex: (->
    bucket = App.router.get('bucketsController').get 'selectedBucket'

    if @selectedTaskIndexes[bucket.id] >= bucket.tasks.length
      @selectedTaskIndexes[bucket.id] = bucket.tasks.length - 1

    if @selectedTaskIndexes[bucket.id] < 0
      @selectedTaskIndexes[bucket.id] = 0

    @selectedTaskIndexes[bucket.id]
  ).property().volatile()

  selectedTask: (->
    bucket = App.router.get('bucketsController').get 'selectedBucket'
    bucket.tasks.objectAt @get('selectedTaskIndex')
  ).property().volatile()

  selectPreviousTask: ->
    bucket = App.router.get('bucketsController').get 'selectedBucket'
    selectedIndex = @get 'selectedTaskIndex'
    if selectedIndex > 0
      bucket.tasks.objectAt(selectedIndex).set 'selected', false
      @selectedTaskIndexes[bucket.id]--
      @updateSelection()

  selectNextTask: ->
    bucket = App.router.get('bucketsController').get 'selectedBucket'
    selectedIndex = @get 'selectedTaskIndex'
    if selectedIndex < bucket.tasks.length - 1
      bucket.tasks.objectAt(selectedIndex).set 'selected', false
      @selectedTaskIndexes[bucket.id]++
      @updateSelection()

  updateSelection: ->
    bucket = App.router.get('bucketsController').get 'selectedBucket'
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
    selectedBucket = App.router.get('bucketsController').get 'selectedBucket'
    taskIndex = selectedBucket.tasks.indexOf task
    if taskIndex is 0
      $('html, body').animate scrollTop: 0, '100'

