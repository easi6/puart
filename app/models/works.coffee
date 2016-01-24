path = require 'path'
logger = require path.join RootPath, "config", "logger"

module.exports = (sequelize, DataTypes) ->
  Work = sequelize.define 'Work',
    # attributes
      title: DataTypes.STRING
      date: DataTypes.DATE
      place: DataTypes.STRING
      dimension: DataTypes.STRING
      material: DataTypes.STRING
      category: DataTypes.STRING
      description: DataTypes.TEXT
    ,
      underscored: true
      freezeTableName: true
      tableName: "works"

      getterMethods:
        _model_name: ->
          @Model.name

      classMethods:
        associate: (models) ->
          Work.belongsTo models.Artist
          Work.hasMany models.WorkImage
          Work.hasOne models.WorkImage,
            { foreignKey: "work_id", as: "featuredImage", scope: featured: true }

  Work.afterDestroy (instance, opt) ->
    Models.WorkImage.destroy(where: work_id: instance.id, individualHooks: true)

  return Work

