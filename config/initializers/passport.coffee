passport = PassportService
LocalStrategy = require('passport-local').Strategy
BearerStrategy = require('passport-http-bearer').Strategy
BasicStrategy = require('passport-http').BasicStrategy
ClientPasswordStrategy = require('passport-oauth2-client-password').Strategy
RememberMeStrategy = require('passport-remember-me').Strategy
Promise = require 'bluebird'
config = require 'config'
bcrypt = require 'bcrypt'
crypto = require 'crypto'
util = require 'util'
path = require 'path'
logger = require path.join RootPath, "config", "logger"
http = require 'http'

module.exports = (app, db) ->

  passport.use "admin-local", new LocalStrategy (username, password, done) ->
    db.Admin.find(where: username: username)
      .then (admin) ->
        if !admin?
          return done null, false, message: "Incorrent username"

        bcrypt.compare password, admin.password_hashed, (err, res) ->
          unless res
            return done null, false, message: "Incorrect password"

          done null, admin
      .catch (err) ->
        done err

  passport.serializeUser (user, done) ->
    done null, "#{user.id}_#{user.Model.name}"

  passport.deserializeUser (str, done) ->
    arr = str.split "_"
    id = parseInt arr[0]
    model_name = arr[1]

    db[model_name].find(where: id: id)
      .then (user) ->
        done null, user
      .catch (err) ->
        done err

  #global filter for authenticated request
  global["AdminAuthed"] = () ->
    [].concat.apply [(req, res, next) ->
      if !(req.isAuthenticated() && req.user.Model.name == "Admin")
        return res.redirect "/admin/login"
      next()
    ], arguments

  logger.verbose "Express middleware for passport"

# vim: set ts=2 sw=2:
