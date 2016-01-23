path = require 'path'
express = require 'express'
config = require 'config'
glob = require 'glob'
passport = require "passport"
router = express.Router()
fs = require 'fs'
util = require 'util'
serveStatic = require 'serve-static'
cookieParser = require "cookie-parser"
session = require 'express-session'
flash = require 'connect-flash'
cors = require 'cors'
Promise = require 'bluebird'
onFinished = require('on-finished')
co = require 'co'
moment = require 'moment'

# expose root path for future usage
RootPath = path.dirname require.main.filename
global["RootPath"] = RootPath

path = require 'path'

app = express()

# default middlewares
# setup logger
# 0. winston
logger = require path.join RootPath, "config", "logger"
errorLogger = logger.errorLogger
# 1. morgan
logformat = "END :req[X-Real-IP] - \":method :url HTTP/:http-version\" :status
            :res[content-length] \":user-agent\" (:response-time ms)"
morgan = require 'morgan'


app.use morgan(logformat, {stream: logger.stream})

bodyparser = require('body-parser')
app.use bodyparser.urlencoded(extended: true)
app.use bodyparser.json()
app.use cookieParser "easi6 easiway"
app.use session
  saveUninitialized: true
  resave: true
  secret: "puart"

app.use (req, res, next) ->
  # change old res.end, res.write with new ones for response logging
  old_end = res.end
  res.end = (chunk) ->
    if chunk? && !res.skip_logging
      res.response_str = chunk.toString()
      isJson = res._headers?['content-type']?.indexOf('json') >= 0
      isPlain = res._headers?['content-type']?.indexOf('plain') >= 0
      if isJson
        logger.verbose "response:\n#{res.response_str}"
        str = JSON.stringify(JSON.parse(res.response_str), null, 2)
      else if isPlain
        logger.verbose "response:\n#{res.response_str}"
    old_end.apply(res, arguments)

  next()


# LESS middleware
lessMiddleware = require 'less-middleware'
app.use '/css', lessMiddleware path.join RootPath, "app", "assets", "css"

# static files
app.use '/uploads', serveStatic './uploads'
app.use '/css', serveStatic './app/assets/css'
app.use '/js', serveStatic './app/assets/js'
app.use '/img', serveStatic './app/assets/img'


app.use '/admin/img', serveStatic './app/assets/admin/img'
app.use '/admin/css', serveStatic './app/assets/admin/css'
app.use '/admin/js', serveStatic './app/assets/admin/js'
app.use '/admin/fonts', serveStatic './app/assets/admin/fonts'

app.use '/bower', serveStatic './app/assets/bower_components'

app.use flash()
app.use passport.initialize()
app.use passport.session()

# rendering view engine set
app.set "views", "./app/views"
app.set "view engine", "jade"
app.engine "jade", require("jade").__express

# long stacktrace for promise debugging
Promise.longStackTraces()

# load glboal services
glob "#{RootPath}/config/services/*.coffee", (err, files) ->
  if err
    throw err

  files.forEach (file) ->
    require(file)(app)

# load models
db = require './app/models'

force_sync = process.env.NDOE_ENV == 'test'
db
  .sequelize
  .sync(force: force_sync)
  .complete (err) ->
    if err?
      console.dir err
      throw err[0]

    # load initializers
    files = glob.sync "#{RootPath}/config/initializers/*.coffee"
    files.forEach (file) ->
      f = require(file)
      if typeof f == 'function'
        if f.length >= 1
          f app, db
        else
          f()

    global["Models"] = db

    app.use (req, res, next) ->
      logger.info("BEGIN #{req.headers["x-real-ip"] || req.headers["x-forwarded-for"]} - \"#{req.method}
                   #{req.url} HTTP/#{req.httpVersion}\"")
      if Object.keys(req.body).length > 0
        sensitive_keys = ["password", "new_password", "card_number", "card_cvv", "password_confirm"]
        old_vals = {}
        for key in sensitive_keys
          if req.body[key]?
            old_vals[key] = req.body[key]
            req.body[key] = "[FILTERED]"
        str = JSON.stringify(req.body, null, 2)
        for k, v of old_vals
          req.body[k] = v
        logger.verbose "parameter: \n#{str}"
      next()

    # route setup
    require("#{RootPath}/config/routes.coffee") router
    app.use router

    # install error handling middleware
    app.use (err, req, res, next) ->
      console.error err.stack
      E res, err

    port = process.env.PORT || config.host.port || 9000
    intfc = process.env.INTERFACE || "127.0.0.1"
    app.listen parseInt(port), intfc
    logger.verbose "Server is listening on port #{port}"

    # 현재 server pid 씀
    pidpath = path.join RootPath, ".server.#{app.settings.env}.pid"
    pidfd = fs.openSync pidpath, "w"
    fs.writeSync pidfd, process.pid
    fs.closeSync pidfd
    logger.verbose "pid is written to #{pidpath}"

# vim: set ts=2 sw=2:
