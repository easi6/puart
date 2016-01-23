module.exports = (sequelize, DataTypes) ->
  WorkImage = sequelize.define 'WorkImage',
    # attributes
      position: DataTypes.INTEGER
      path: DataTypes.STRING # actual image file path
    ,
      underscored: true
      freezeTableName: true
      tableName: "work_images"

      getterMethods:
        _model_name: ->
          @Model.name

      classMethods:
        associate: (models) ->
          WorkImage.belongsTo models.Work

  return WorkImage


