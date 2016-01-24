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
myutil = require path.join RootPath, "lib", "util"
moveUploadedFile = myutil.moveUploadedFile
url = require 'url'

class AdminWorkController
  index: SkipLog AdminAuthed SetPath Paginated(20) (req, res) ->
    co ->
      Model = db.Work

      per_page = req.query.limit
      page = req.query.page

      {count: count, rows:works} = yield db.Work.findAndCountAll
        limit: page
        offset: (page-1)*per_page
        order: [["id", "DESC"]]

      _page_count = parseInt Math.ceil(count/per_page)

      _.extend res.locals,
        model: Model, records: works, works: works, inflection: inflection,
        moment: moment, ellipsize: ellipsize, req: req, total_page: _page_count

      res.render "admin/works/index"
    .catch (err) ->
      E res, err

  show: SkipLog AdminAuthed SetPath FindWork (req, res) ->
    co ->
      work_images = yield req.work.getWorkImages()

      _.extend res.locals, model: db.Work, inflection: inflection, ellipsize: ellipsize,
        record: req.work, work: req.work, work_images: work_images, moment: moment
      res.render "admin/works/show"
    .catch (err) ->
      E res, err

  edit: SkipLog AdminAuthed SetPath FindWork (req, res) ->
    co ->
      work_images = yield req.work.getWorkImages()
      work_images = work_images.map (w) -> w.get()
      artists = yield db.Artist.findAll(order: [["name", "ASC"]])

      _.extend res.locals,
        record: req.work, work: req.work, work_images: work_images,
        moment: moment, model: db.Work, inflection: inflection, ellipsize: ellipsize,
        artists: artists

      res.render "admin/works/edit"
    .catch (err) ->
      E res, err

  new: SkipLog AdminAuthed SetPath (req, res) ->
    co ->
      work = db.Work.build()
      artists = yield db.Artist.findAll(order: [["name", "ASC"]])

      _.extend res.locals,
        record: work, work: work, work_images: [], artists: artists
        moment: moment, model: db.Work, inflection: inflection, ellipsize: ellipsize

      res.render "admin/works/new"
    .catch (err) ->
      E res, err

  create: SkipLog AdminAuthed (req, res) ->
    co ->
      work = null
      yield db.sequelize.transaction (tx) ->
        co ->
          work = yield db.Work.create(req.body.work, transaction: tx)
          yield Promise.map req.body.work_images, (infos) ->
            [name, path, size] = infos.split(";")
            db.WorkImage.create({
              work_id: work.id, name: name, path: path, size: parseInt(size)
            }, transaction: tx)

      res.redirect "/admin/works/#{work.id}"
    .catch (err) ->
      E res, err

  update: SkipLog AdminAuthed FindWork (req, res) ->
    co ->
      db.sequelize.transaction (tx) ->
        co ->
          yield req.work.updateAttributes(req.body.work)
          yield Promise.map req.body.work_images, (infos) ->
            [name, path, size] = infos.split(";")
            db.WorkImage.create({
              work_id: req.work.id, name: name, path: path, size: parseInt(size)
            }, transaction: tx)

      res.redirect "/admin/works/#{req.work.id}"
    .catch (err) ->
      E res, err

  destroy: SkipLog AdminAuthed FindWork (req, res) ->
    co ->
      yield req.work.destroy()
      res.redirect "/admin/works"
    .catch (err) ->
      E res, err

  delete_images: SkipLog AdminAuthed (req, res) ->
    co ->
      unlink = Promise.promisify(fs.unlink)
      if parseInt(req.query.id) > 0
        yield db.WorkImage.find(where: id: req.query.id).then (img) ->
          img.destroy()
        obj = files: {}
        obj.files[req.query.name] = true
        res.send obj
      else
        console.dir req.body
        path = RootPath + req.query.filename
        yield unlink(path)
        yield db.WorkImage.build(path: path).thumb_path
        obj = files: {}
        obj.files[req.query.name] = true
        res.send obj
    .catch (err) ->
      E res, err

  upload_images: SkipLog AdminAuthed Multiparted (req, res) ->
    co ->
      console.log req.files
      arr = yield Promise.map req.files.work_images, (img) ->
        moveUploadedFile(img).then (img_path) ->
          db.WorkImage.build(name: img.name, size: img.size, path: img_path)

      res.send files: arr
    .catch (err) ->
      E res, err

module.exports = new AdminWorkController
# vim: set ts=2 sw=2 :
