window.setupShorcuts = ->
  $("input").live 'keydown', (e) ->
    switch e.keyCode
      when 27 # remove the focus from the input when the escape key is pressed
        $(this).blur()
        App.router.get('commandBoxController').hide()
        return false
      when 74 # ctrl-j triggers the submit event of the command form
        if e.ctrlKey
          $(this).closest('form').submit()
          return false

  $('#command').live 'keyup', (e) ->
    switch e.keyCode
      when 8, 88, 72, 46 # ensured that the starting colon can't de deleted (backspace, cmd/ctrl+x, ctrl+h, delete)
        if $(this).val().length is 0
          $(this).val(':')

  $(document).keydown (e) ->
    if $(document.activeElement)[0] is $(document.body)[0]
      switch e.keyCode
        when 74 # j
          App.router.get('tasksController').selectNextTask()
        when 75 # k
          App.router.get('tasksController').selectPreviousTask()
        when 72 # h
          App.router.get('bucketsController').selectPreviousBucket()
        when 76 # l
          App.router.get('bucketsController').selectNextBucket()
        when 191,186,59 # :
          App.router.get('commandBoxController').show()
        when 27
          App.router.get('commandBoxController').hide()
          return false # needed because of firefox on mac os x

window.configureWebsocket = ->
  socket = io.connect('http://localhost')
  socket.on 'connect', ->
    console.log "Connected to server"
    App.initialize()
    App.router.get('commandBoxController').initialize()
    setupShorcuts()
    console.log "Application started"

  socket.on 'update bucket', (data) ->
    console.log "update bucket:", data
    App.router.get('tasksController').fetchBucketTasks(data.bucket)

