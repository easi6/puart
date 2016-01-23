inflection = require 'inflection'
module.exports = (app, db) ->
  for model_name, model of db
    unless model_name.match(/sequelize/i)
      f = ((model_name, model) ->
        () ->
          filter = (req, res, next) ->
            clause = where: id: req.params.id
            model.find(clause)
            .then (r) ->
              if !r?
                return E(res, "#{inflection.underscore(model_name)}_not_found", req.params.id)
              req[inflection.underscore(model_name)] = r
              next()
            .catch (err) -> server_error(res, err)
          [].concat.apply [filter], arguments
      )(model_name, model)
      global["Find#{model_name}"] = f
# vim: set ts=2 sw=2 :

