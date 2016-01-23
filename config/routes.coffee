glob = require 'glob'
path = require 'path'

module.exports = (router) ->
  controllers = {}


  # route construct helper function
  R = (str) ->
    [c, a] = str.split "#"
    controller = controllers[c]
    f = if controller? then controller[a] else (req, res, next) -> res.send 500, "controller `#{c}` doesn't exist!"

    if !f
      (req, res, next) ->
        res.send 500, "action `#{str}` isn't implemented yet!"
    else
      [
        (req, res, next) ->
          req.controller_name = c
          req.action_name = a
          next()
        , f
      ]

  # load all controllers
  glob "#{RootPath}/app/controllers/**/*.coffee", (err, files) ->
    if err
      throw err
    files.forEach (file) ->
      fileName = path.relative "#{RootPath}/app/controllers/", file
      controllerName = fileName.match(/(.*)_controller/)[1]
      controllers[controllerName] = require file

    # === admin page ===
    router.get  "/admin",                            R("admin/admin#dashboard")
    router.get  "/admin/dashboard",                  R("admin/admin#dashboard")
    router.get  "/admin/login",                      R("admin/admin#login")
    router.post "/admin/login",                      PassportService.authenticate("admin-local", { successRedirect: "/admin", failureRedirect: "/admin/login", failureFlash: true})
