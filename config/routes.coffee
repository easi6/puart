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

    # === main page ===
    router.get "/",      R("home#main")

    # === works db page ===
    router.get "/works",     R("works#index")
    router.get "/works/:id", R("works#show")

    # === admin page ===
    router.get  "/admin",           R("admin/admin#dashboard")
    router.get  "/admin/dashboard", R("admin/admin#dashboard")
    router.get  "/admin/login",     R("admin/admin#login")
    router.post "/admin/login",     PassportService.authenticate("admin-local", 
      {
        successRedirect: "/admin",
        failureRedirect: "/admin/login",
        failureFlash: true
      })


    # === works management ===
    router.get  "/admin/works",             R("admin/works#index")
    router.get  "/admin/works/new",         R("admin/works#new")
    router.post "/admin/works/upload_images",R("admin/works#upload_images")
    router.post "/admin/works/delete_images",R("admin/works#delete_images")
    router.post "/admin/works",             R("admin/works#create")
    router.get  "/admin/works/:id",         R("admin/works#show")
    router.get  "/admin/works/:id/edit",    R("admin/works#edit")
    router.post "/admin/works/:id/update",  R("admin/works#update")
    router.post "/admin/works/:id/destroy", R("admin/works#destroy")

    # === model admin fallback ===
    router.get  "/admin/:model_name",                R("admin/admin#model_list")
    router.get  "/admin/:model_name/new",            R("admin/admin#model_new")
    router.get  "/admin/:model_name/:id",            R("admin/admin#model_show")
    router.post "/admin/:model_name",                R("admin/admin#model_create")
    router.get  "/admin/:model_name/:id/edit",       R("admin/admin#model_edit")
    router.post "/admin/:model_name/:id/update",     R("admin/admin#model_update")
    router.put  "/admin/:model_name/:id",            R("admin/admin#model_update")
    router.post "/admin/:model_name/:id/destroy",    R("admin/admin#model_delete")
    router.delete "/admin/:model_name/:id",          R("admin/admin#model_delete")
