db = require "#{RootPath}/app/models"
util = require 'util'
config = require 'config'
E = require "#{RootPath}/lib/err.coffee"
fs = require 'fs'
_ = require 'lodash'
Promise = require 'bluebird'
inflection = db.sequelize.Utils.inflection
moment = require "moment"
ellipsize = require 'ellipsize'
co = require 'co'
jade = require 'jade'
path = require 'path'
logger = require path.join RootPath, "config", "logger"

class HomeController

  main: (req, res, next) ->
    res.render "index"

module.exports = new HomeController
# vim: set ts=2 sw=2 :


