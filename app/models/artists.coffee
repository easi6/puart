module.exports = (sequelize, DataTypes) ->
  Artist = sequelize.define 'Artist',
    # attributes
      name: DataTypes.STRING
    ,
      underscored: true
      freezeTableName: true
      tableName: "artists"

      getterMethods:
        _model_name: ->
          @Model.name

      classMethods:
        associate: (models) ->
          Artist.hasMany models.Work


  return Artist
