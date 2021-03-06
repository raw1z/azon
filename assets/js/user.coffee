window.App.UserFormView = Ember.View.extend
  templateName: 'user-form'
  tagName: 'form'
  classNames: ['form']
  attributeBindings: ['action', 'method']
  method: 'post'
  actionBinding: 'parentView.action'
  iconBinding: 'parentView.icon'
  titleBinding: 'parentView.title'
  elementId: 'user-form'

window.App.LoginView = Ember.View.extend
  templateName: 'login'
  action: '/login.json'
  title: 'Login'
  didInsertElement: ->
    $('#user-form input[type="text"]').focus()
    $('#user-form').submit (event) ->
      event.preventDefault()
      $(this).ajaxSubmit (data) ->
        App.router.get('applicationController').set 'currentUserId', new User(data.userId) if data.userId
        App.router.transitionTo 'index'

window.App.RegisterView = App.LoginView.extend
  action: '/register.json'
  title: 'Register'

window.App.User = Ember.Object.extend
  username: null
  id: (->
    @_id
  ).property()

window.App.LoginController = Ember.Controller.extend()
window.App.RegisterController = Ember.Controller.extend()
