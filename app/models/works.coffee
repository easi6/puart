module.exports = (sequelize, DataTypes) ->
  Work = sequelize.define 'Work',
    # attributes
      title: DataTypes.STRING
      date: DataTypes.DATE
      place: DataTypes.STRING
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

  return Work

