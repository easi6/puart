bcrypt = require 'bcrypt'

module.exports = (sequelize, DataTypes) ->
  Admin = sequelize.define 'Admin',
    # attributes
      username:
        type: DataTypes.STRING
        allowNull: false
      password_hashed:
        type: DataTypes.STRING
        allowNull: false
      type:
        type: DataTypes.INTEGER
        allowNull: false
        defaultValue: 0 # 0 means SUPER
    ,
      # sequelize 모델의 네이밍 기본 동작을 Rails스럽게
      underscored: true
      freezeTableName: true
      tableName: "admins"

      setterMethods:
        password: (password) ->
          password_hashed = bcrypt.hashSync password, bcrypt.genSaltSync()
          this.setDataValue "password_hashed", password_hashed
  return Admin
