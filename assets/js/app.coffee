window.App = Ember.Application.create

  ApplicationController: Ember.Controller.extend
    currentUser: (->
      user = null
      $.ajaxSetup async: false
      $.getJSON "/user.json", (data) ->
        user = data.user
      return user
    ).property().volatile()

  ApplicationView: Ember.View.extend
    templateName: 'application'

  Router: Ember.Router.extend
    root: Ember.Route.extend
      index: Ember.Route.extend
        route: '/'

        showLoginForm: (router, context) ->
          router.transitionTo 'login', context

        showRegisterForm: (router, context) ->
          router.transitionTo 'register', context

        showBuckets: (router, context) ->
          router.transitionTo 'buckets', context

        connectOutlets: (router, context) ->
          if router.get('applicationController').get('currentUser')
            router.send 'showBuckets'
          else
            router.get('applicationController').connectOutlet 'home'

      buckets: Ember.Route.extend
        route: '/buckets'
        connectOutlets: (router, context) ->
          if router.get('applicationController').get('currentUser')
            router.get('applicationController').connectOutlet 'buckets'
          else
            window.location = '/'

      login: Ember.Route.extend
        route: '/login'

        connectOutlets: (router, context) ->
          if router.get('applicationController').get('currentUser')
            router.transitionTo 'buckets', context
          else
            router.get('applicationController').connectOutlet 'login'

      register: Ember.Route.extend
        route: '/register'
        connectOutlets: (router, context) ->
          if router.get('applicationController').get('currentUser')
            router.transitionTo 'buckets', context
          else
            router.get('applicationController').connectOutlet 'register'

