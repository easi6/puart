SkipLog = ->
  filter = (req, res, next) ->
    res.skip_logging = true
    next()

  [].concat.apply [filter], arguments

global["SkipLog"] = SkipLog
module.exports = SkipLog

# vim: set ts=2 sw=2 :

