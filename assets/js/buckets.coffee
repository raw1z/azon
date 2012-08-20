#############################################################################################
# Model
#############################################################################################
window.App.Bucket = Ember.Object.extend
  id: null
  name: null
  position: 0
  selected: false
  tasks: []

window.App.Bucket.reopenClass
  all: ->
    buckets = []
    for id, name of {today: 'Today', tomorrow: 'Tomorrow', twoDaysFromNow: 'Two days from now', future: 'Future'}
      bucket = App.Bucket.create
        id: id
        name: name
      buckets.pushObject bucket

    buckets[0].set 'selected', true
    return buckets

#############################################################################################
# Views
#############################################################################################
window.App.BucketView = Ember.View.extend
  templateName: 'bucket'
  tagName: 'section'
  classNameBindings: ['label', 'spanWidth', 'content.selected']
  label: 'bucket'
  spanWidth: (() -> "span#{12/App.router.get("bucketsController").content.length}").property()
  titleBinding: 'content.name'
  number: (->
    switch @content.id
      when 'today' then 1
      when 'tomorrow' then 2
      when 'twoDaysFromNow' then 3
      when 'future' then 4
  ).property()

window.App.BucketCollectionView = Ember.CollectionView.extend
  classNames: ['row-fluid']
  itemViewClass: App.BucketView
  elementId: 'buckets'

window.App.BucketsView = Ember.View.extend
  templateName: 'buckets'
  didInsertElement: ->
    @get('controller').set 'content', App.Bucket.all()
    App.router.get('tasksController').fetchTasks()
    Ember.run.next ->
      $('#logout-link').click (event) ->
        event.preventDefault()
        $(this).closest('form').submit()

#############################################################################################
# Controllers
#############################################################################################
window.App.BucketsController = Ember.ArrayController.extend
  content: []
  selectedBucketIndex: 0

  populateBucket: (bucketId, tasks) ->
    console.log 'populate bucket:', bucketId, tasks
    for bucket in @content when bucket.id == bucketId
      bucket.set 'tasks', []
      for object in tasks
        bucket.tasks.pushObject App.Task.create(object)

      selectedIndex = App.router.get('tasksController').get 'selectedTaskIndex'
      bucket.tasks[selectedIndex]?.set 'selected', true

  selectedBucket: (->
    @content.objectAt @selectedBucketIndex
  ).property().volatile()

  selectPreviousBucket: ->
    if @selectedBucketIndex > 0
      @content.objectAt(@selectedBucketIndex).set "selected", false
      @content.objectAt(@selectedBucketIndex-1).set "selected", true
      @selectedBucketIndex--
      App.router.get('tasksController').updateSelection()

  selectNextBucket: ->
    if @selectedBucketIndex < @content.length - 1
      @content.objectAt(@selectedBucketIndex).set "selected", false
      @content.objectAt(@selectedBucketIndex+1).set "selected", true
      @selectedBucketIndex++
      App.router.get('tasksController').updateSelection()
