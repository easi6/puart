winston = require 'winston'
winston.emitErrs = true
config = require 'config'
moment = require 'moment'
path = require 'path'

transports = [
  new winston.transports.Console
    level: 'debug'
    handleExceptions: true
    json: false
    colorize: true
    timestamp: true
]

# read from config add transports
for trans in config.winston.transports
  type = trans.type
  delete trans.type
  transports.push new winston.transports[type](trans)

logger = new winston.Logger
  transports: transports
  exitOnError: false

dblogger = new winston.Logger
  transports:[
    new winston.transports["DailyRotateFile"]
      level: "debug"
      filename: "./logs/db.log"
      handleExceptions: true
      json: false
      maxsize: 104857600
      colorize: false
  ]
  exitOnError: false

errlogger = new winston.Logger
  transports: [
    new winston.transports["DailyRotateFile"]
      level: "debug"
      filename: "./logs/err.log"
      handleExceptions: true
      json: false
      maxsize: 104857600
      colorize: false
  ]
  exitOnError: false

module.exports = logger

module.exports.errorLogger =
  createLog: (req, res) ->
    ua = req.headers["user-agent"]
    if req.user?
      userstr = "#{req.user?.Model.name}(#{req.user?.id})"

    if Object.keys(req.body).length > 0
      sensitive_keys = ["password", "new_password", "card_number", "card_cvv", "password_confirm"]
      old_vals = {}
      for key in sensitive_keys
        if req.body[key]?
          old_vals[key] = req.body[key]
          req.body[key] = "[FILTERED]"
      str = JSON.stringify(req.body)
      for k, v of old_vals
        req.body[k] = v

    error_string = """
    \n==== error response ====
    user: #{userstr}
    ua: #{req.headers['user-agent']}
    request_path: #{req.method} #{req.url} HTTP/#{req.httpVersion}
    request_body: #{str}
    response_code: #{res.statusCode}
    request_headers: #{JSON.stringify(req.headers)}
    response_body: #{res.response_str}
    """
    error_string = error_string.replace(/[^\S\r\n]+$/gm, "")
    errlogger.error error_string

module.exports.stream =
  write: (message, encoding) ->
    logger.info message[0..-2]
  db: (message, encoding) ->
    dblogger.verbose message

