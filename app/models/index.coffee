# see http://sequelizejs.com/articles/express

_ = require 'lodash'
fs = require 'fs'
glob = require 'glob'
path      = require 'path'
Sequelize = require 'sequelize'
config    = require 'config'
logger = require path.join RootPath, "config", "logger"
write = logger.stream.db

sequelize = new Sequelize config.database.database, config.database.username, config.database.password,
  host: config.database.host
  dialect: config.database.dialect
  storage: "#{RootPath}/#{config.database.storage}"
  logging: write
db        = {}

glob.sync("#{__dirname}/**/*.coffee")
  .filter((file) -> (file.indexOf('.') != 0) && (path.basename(file) != 'index.coffee'))
  .forEach (file) ->
    return if path.extname(file) != ".coffee"
    logger.verbose "importing #{path.relative(__dirname, file)}..."
    model = sequelize.import(file)
    db[model.name] = model

for modelName, model of db
  logger.verbose "associating #{modelName}"
  if 'associate' of model
    model.associate db

module.exports = _.extend
  sequelize: sequelize
  Sequelize: Sequelize
  , db

