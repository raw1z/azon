express = require 'express' 
stylus  = require 'stylus'
routes  = require './routes' 
http    = require 'http' 

app = express()

app.configure ->
  publicDir = "#{__dirname}/public"
  viewsDir = "#{__dirname}/views"

  app.set 'port', process.env.PORT || 3000
  app.set 'views', viewsDir
  app.set 'view engine', 'jade'
  app.use express.favicon()
  app.use express.logger('dev')
  app.use express.bodyParser()
  app.use express.methodOverride()
  app.use express.cookieParser('your secret here')
  app.use express.session()
  app.use app.router
  app.use require('connect-assets')()
  app.use express.static(publicDir)

app.configure 'development', ->
  app.use express.errorHandler()

app.get '/', routes.index
app.get '/buckets/:bucket/tasks.json', routes.tasks
app.post '/command.json', routes.command

server = http.createServer(app).listen app.get('port'), ->
  console.log("Express server listening on port " + app.get('port'));

mongoose = require 'mongoose'
mongoose.connect 'localhost', '#azon', (err) ->
  throw err if err

global.io = require('socket.io').listen(server, 'log level':2)

