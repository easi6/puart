paginate = require 'express-paginate'
middleware = paginate.middleware(20,50)
Paginated = () ->
  if arguments.length == 1 && typeof arguments[0] == "number"
    middleware = paginate.middleware(arguments[0], 50)
    () ->
      [].concat.apply [middleware], arguments
  else
    [].concat.apply [middleware], arguments
global["Paginated"] = Paginated
module.exports = Paginated


