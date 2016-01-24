path = require 'path'
url = require 'url'
fs = require 'fs'
Promise = require 'bluebird'
logger = require path.join RootPath, "config", "logger"

unlink = Promise.promisify(fs.unlink)
module.exports = (sequelize, DataTypes) ->
  WorkImage = sequelize.define 'WorkImage',
    # attributes
      name: DataTypes.STRING # original file name
      size: DataTypes.INTEGER # filesize
      position: DataTypes.INTEGER
      path: DataTypes.STRING # actual image file path
      featured:
        type: DataTypes.BOOLEAN
        allowNull: false
        defaultValue: false
    ,
      underscored: true
      freezeTableName: true
      tableName: "work_images"

      getterMethods:
        _model_name: ->
          @Model.name

        thumb_path: ->
          ext = path.extname(@path)
          basename = path.basename(@path, ext)
          dirname = path.dirname(@path)
          path.join(dirname, "#{basename}_t#{ext}")

        thumbnailUrl: -> @thumb_path

        url: -> @path
        size: 0

        deleteUrl: ->
          url.format(pathname: "/admin/works/delete_images", query:{id: @id, filename: @path, name: @name})
        deleteType: -> "POST"


      classMethods:
        associate: (models) ->
          WorkImage.belongsTo models.Work

  WorkImage.afterDestroy (instance, opt) ->
    logger.verbose "workimage.afterdestroy"
    Promise.join(unlink(RootPath + instance.thumb_path),
      unlink(RootPath + instance.path))
    .catch (err) ->
      return true
      # do nothing

  return WorkImage


