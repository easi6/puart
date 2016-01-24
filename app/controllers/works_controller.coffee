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

  index: Paginated(20) (req, res, next) ->
    co ->
      per_page = req.query.limit
      page = req.query.page

      works = yield db.Work.findAll
        limit: per_page
        offset: (page-1)*per_page
        include: [{model: db.WorkImage, as:"featuredImage"}, {model: db.Artist}]

      logger.verbose "works.length=#{works.length}"

      _.extend res.locals, works: works, moment: moment
      res.render "works/index"

    .catch (err) ->
      E res, err

  show: FindWork (req, res, next) ->
    co ->
      images = yield req.work.getWorkImages()
      featured_image = yield req.work.getFeaturedImage()
      artist = yield req.work.getArtist()

      _.extend res.locals,
        work: req.work, images: images, moment: moment,
        artist: artist, featured_image: featured_image
      res.render "works/show"
    .catch (err) ->
      E res, err

  search: (req, res) ->
    co ->
      artists = yield db.Artist.findAll(where: name: $like: "%#{req.query.query}%")
      artist_ids = artists.map (a) -> a.id
      works = yield db.Work.findAll
        where: $or: [
          {title: $like: "%#{req.query.query}%"},
          {artist_id: artist_ids}
        ]
        include: [{model: db.WorkImage, as:"featuredImage"}, {model: db.Artist}]

      _.extend res.locals, works: works, moment: moment
      res.render "works/index"
    .catch (err) ->
      E res, err

module.exports = new HomeController
# vim: set ts=2 sw=2 :



