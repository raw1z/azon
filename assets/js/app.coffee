window.App = Ember.Application.create
  ready: ->
    App.router.get('commandBoxController').initialize()

    configureWebsocket()
    setupShorcuts()

    console.log "Application started"

  ApplicationController: Ember.Controller.extend
    currentUser: null

  ApplicationView: Ember.View.extend
    templateName: 'application'

  Router: Ember.Router.extend
    root: Ember.Route.extend
      index: Ember.Route.extend
        route: '/'
        connectOutlets: (router, event) ->
          router.get('applicationController').connectOutlet 'buckets', App.Bucket.all()

