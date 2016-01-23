SetPath = ->
  filter = (req, res, next) ->
    res.locals.path = req.path.replace(/\/+$/, "")
    next()
  [].concat.apply [filter], arguments

global["SetPath"] = SetPath
module.exports = SetPath
# vim: set ts=2 sw=2 :
