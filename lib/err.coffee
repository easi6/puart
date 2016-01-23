util = require 'util'
path = require 'path'
logger = require path.join RootPath, "config", "logger"

# 에러 코드 통일을 위한 라이브러리
# JSON으로 표시되는 error를 리턴한다.

# from http://stackoverflow.com/a/14263681/2213319
String.prototype.format = ->
  args = arguments
  return this.replace /{(\d+)}/g, (match, number) ->
    return if typeof args[number] isnt 'undefined' then args[number] else match

E = (res, code, __var_args__) ->
  if typeof code == "object"
    err = code
    unless res.error_logging
      res.error_logging = err.logging
    # http_status가 박혀있다는 것은 easiway 자체에서 만들어낸 오류라고
    # 예상되는 오류들이다. 하지만 500일 경우는 로그를 죄다 출력한다.
    # error_logging은 무조건 수행
    if !err.http_status? || err.http_status == 500
      res.error_logging = true
      logger.error err.stack
    return res.json err.http_status ? 500, {error: err.code, message: err.message}

  a = err_list[code]
  status = a[0]
  tmpl = a[1]
  should_log = !!a[2]

  # see https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Functions_and_function_scope/arguments
  # arguments 자체는 어레이가 아님
  args = Array.prototype.slice.call(arguments)
  args = args[2..]

  message = tmpl["format"].apply tmpl, args
  res.error_logging = should_log
  res.json status, {error: code, message: message}

logger.verbose "register 'E' function to global"
global["E"] = E

###############################################################

server_error = (res, err) ->
  E res, "server_error", err.message
logger.verbose "register 'server_error' function to global"
global["server_error"] = server_error

err_list =
  # 아래에 필요한 것을 하나씩 추가합니다.
  # 중복되는 것이 있지 않은지 체크!
  record_not_found: [404, "record with id {0} couldn't be found"]
  user_not_found: [404, "user with id {0} couldn't be found"]
  server_error: [500, "{0}", true]
  access_denied: [404, "not allowed"]
  no_argument: [400, "{0} needed"]
  invalid_parameter: [400, "parameter {0} value {1} invalid"]

Err = (code, __var_args__) ->
  a = err_list[code]
  status = a[0]
  tmpl = a[1]
  logging = !!a[2]

  # see https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Functions_and_function_scope/arguments
  # arguments 자체는 어레이가 아님
  args = Array.prototype.slice.call(arguments)
  args = args[1..]

  message = tmpl["format"].apply tmpl, args
  e = new Error(message)
  e.code = code
  e.http_status = status
  e.status = status
  e.logging = logging
  e
global["Err"] = Err

module.exports = E

