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

class AdminController

  find_pkey = (model) ->
    if model.rawAttributes["id"]? then "id" else model.primaryKeyAttributes[0]

  login: SkipLog (req, res, next) ->
    _.extend res.locals, message: req.flash("error")
    res.render "admin/login"

  dashboard: SkipLog AdminAuthed SetPath (req, res, next) ->
    co ->
      _.extend res.locals, message: "hello"
      res.render "admin/dashboard"
    .catch (err) ->
      E res, err

  model_list: SkipLog AdminAuthed SetPath Paginated(20) FindModel (req, res, next) ->
    co ->
      Model = req.model

      per_page = req.query.limit
      page = req.query.page

      promise =
        if Model.rawAttributes["id"]? && Model.rawAttributes["created_at"]?
          Model.findAndCountAll
            hooks: false
            limit: per_page
            offset: (page-1)*per_page
            order: [["id", "DESC"], ["created_at", "DESC"]]
        else if Model.rawAttributes["created_at"]?
          Model.findAndCountAll
            hooks: false
            limit: per_page
            offset: (page-1)*per_page
            order: [["created_at", "DESC"]]
        else
          Model.findAndCountAll
            hooks: false
            limit: per_page
            offset: (page-1)*per_page
      {rows: records, count: count}  = yield promise

      _page_count = parseInt Math.ceil(count/per_page)

      timestamp_attrs = []
      for k, v of Model._timestampAttributes
        timestamp_attrs.push v

      _.extend res.locals,
               model: Model, records: records, inflection: inflection
               moment: moment, ellipsize: ellipsize, timestamps: timestamp_attrs
               total_page: _page_count, req: req
      res.end _templates.model_list res.locals
    .catch (err) ->
      E res, err

  model_show: SkipLog AdminAuthed SetPath FindModel (req, res, next) ->
    co ->
      Model = req.model
      pkey = find_pkey Model

      condition = {}
      condition[pkey] = req.params.id
      record = yield Model.find(hooks: false, where: condition)

      _.extend res.locals,
               record: record, model: Model, moment: moment
               ellipsize: ellipsize, inflection: inflection, req: req
      res.end _templates.model_show res.locals
    .catch (err) ->
      E(res, err)

  model_new: SkipLog AdminAuthed SetPath FindModel (req, res, next) ->
    co ->
      Model = req.model

      record = Model.build()
      _.extend res.locals,
               model: Model, record: record, moment: moment
               ellipsize: ellipsize, inflection: inflection, req: req

      res.end _templates.model_new res.locals
    .catch (err) ->
      E res, err


  model_create: SkipLog AdminAuthed SetPath FindModel (req, res, next) ->
    co ->
      Model = req.model

      for k, v of req.body
        if v.length == 0
          if k == "password"
            delete req.body[k]
          else
            req.body[k] = null
      model = yield Model.create(req.body)
      res.redirect "/admin/#{Model.tableName}/#{model.id}"
    .catch (err) ->
      E(res, err)

  model_edit: SkipLog AdminAuthed SetPath FindModel (req, res, next) ->
    co ->
      Model = req.model
      #console.dir Model
      pkey = find_pkey Model

      condition = {}
      condition[pkey] = req.params.id
      record = yield Model.find(hooks: false, where: condition)

      _.extend res.locals,
               model: Model, record: record, moment: moment
               ellipsize: ellipsize, inflection: inflection, req: req

      res.end _templates.model_edit res.locals
    .catch (err) ->
      E(res, err)

  model_update: SkipLog AdminAuthed SetPath FindModel (req, res, next) ->
    co ->
      Model = req.model
      pkey = find_pkey Model

      condition = {}
      condition[pkey] = req.params.id
      record = yield Model.find(hooks: false, where: condition)
      for k, v of req.body
        if v.length == 0
          if k == "password"
            delete req.body[k]
          else
            req.body[k] = null
      yield record.updateAttributes(req.body)
      res.redirect "/admin/#{Model.tableName}/#{record.id}"
    .catch (err) ->
      E res, err

  model_count: SkipLog AdminAuthed (req, res, next) ->
    co ->
      from = req.query.from? && moment(req.query.from).toDate() || new Date(0)
      to = req.query.to? && moment(req.query.to).toDate() || new Date
      modelName = inflection.capitalize req.params.model
      counts = yield db.ModelCount.getCountsBetween(modelName, from, to)

      res.json counts
    .catch (err) ->
      E res, err

  model_delete: SkipLog AdminAuthed FindModel (req, res, next) ->
    co ->
      Model = req.model
      pkey = find_pkey Model

      condition = {}
      condition[pkey] = parseInt req.params.id
      yield Model.destroy(where: condition)
      res.redirect "/admin/#{Model.tableName}"
    .catch (err) ->
      E(res, err)

module.exports = new AdminController
# vim: set ts=2 sw=2 :

