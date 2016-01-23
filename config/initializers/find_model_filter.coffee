module.exports = (app, db) ->
  inflection = db.sequelize.Utils.inflection
  FindModel = ->
    filter = (req, res, next) ->
      model =
        if req.params.model_name?
          model_name = inflection.classify req.params.model_name
          db[model_name]
      unless model?
        return res.type('text/plain').send "#{model_name} not found"

      req.model = model
      next()
    [].concat.apply [filter], arguments

  global["FindModel"] = FindModel
# vim: set ts=2 sw=2 :

