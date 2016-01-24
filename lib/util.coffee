path = require 'path'
mkdirp = require 'mkdirp'
util = require 'util'
fs = require 'fs'
Promise = require 'bluebird'
crypto = require 'crypto'
kue = require 'kue'
jobs = kue.createQueue()
logger = require path.join RootPath, "config", "logger"
http = require 'http'
https = require 'https'
config = require 'config'
jade = require 'jade'
tmp = require 'tmp'
fs = require 'fs'
moment = require 'moment'
easyimg = require 'easyimage'

Array::unique = ->
  output = {}
  output[@[key]] = @[key] for key in [0...@length]
  value for key, value of output

Array::uniqBy = (pred) ->
  seen = {}
  @filter (item) ->
    k = pred(item)
    if seen.hasOwnProperty(k) then false else (seen[k] = true)


String::substr_utf8_bytes = (startInBytes, lengthInBytes) ->
  encode_utf8 = (s) ->
    unescape encodeURIComponent s

 # this function scans a multibyte string and returns a substring. 
 # arguments are start position and length, both defined in bytes.
 # 
 # this is tricky, because javascript only allows character level 
 # and not byte level access on strings. Also, all strings are stored
 # in utf-16 internally - so we need to convert characters to utf-8
 # to detect their length in utf-8 encoding.
 #
 # the startInBytes and lengthInBytes parameters are based on byte 
 # positions in a utf-8 encoded string.
 # in utf-8, for example: 
 #       "a" is 1 byte, 
 #       "ü" is 2 byte, 
 #  and  "你" is 3 byte.
 #
 # NOTE:
 # according to ECMAScript 262 all strings are stored as a sequence
 # of 16-bit characters. so we need a encode_utf8() function to safely
 # detect the length our character would have in a utf8 representation.
 # 
 # http://www.ecma-international.org/publications/files/ecma-st/ECMA-262.pdf
 # see "4.3.16 String Value":
 # > Although each value usually represents a single 16-bit unit of 
 # > UTF-16 text, the language does not place any restrictions or 
 # > requirements on the values except that they be 16-bit unsigned 
 # > integers.
 #

  resultStr = ''
  startInChars = 0

  # scan string forward to find index of first character
  # (convert start position in byte to start position in characters)

  bytePos = 0
  while bytePos < startInBytes

    # get numeric code of character (is >= 128 for multibyte character)
    # and increase "bytePos" for each byte of the character sequence

    ch = @charCodeAt(startInChars)
    bytePos += if ch < 128 then 1 else encode_utf8(@[startInChars]).length
    startInChars++

  # now that we have the position of the starting character,
  # we can built the resulting substring

  # as we don't know the end position in chars yet, we start with a mix of
  # chars and bytes. we decrease "end" by the byte count of each selected 
  # character to end up in the right position
  end = startInChars + lengthInBytes - 1

  n = startInChars
  while startInChars <= end
    # get numeric code of character (is >= 128 for multibyte character)
    # and decrease "end" for each byte of the character sequence
    ch = @charCodeAt(n)
    end -= if ch < 128 then 1 else encode_utf8(@charAt(n)).length

    resultStr += @charAt(n)
    n++

  return resultStr

String::trim_length = (length) ->
  if Buffer.byteLength(@) > length
    @substr_utf8_bytes(0, length - 3) + "..."
  else
    @

https_get = (url) ->
  new Promise (rs, rj) ->
    response = ""
    https.get url, (res) ->
      res.on "data", (d) ->
        #console.log(d)
        response += d
      res.on "end", () ->
        #console.log(response)
        rs response
    .on "error", (e) -> rj e


http_get = (url) ->
  new Promise (rs, rj) ->
    response = ""
    http.get url, (res) ->
      res.on "data", (d) ->
        #console.log(d)
        response += d
      res.on "end", () ->
        #console.log(response)
        rs response
    .on "error", (e) -> rj e

outOfChina = (lat, lon) ->
  if (lon < 72.004 || lon > 137.8347)
    return true
  if (lat < 0.8293 || lat > 55.8271)
    return true
  return false

pi = Math.PI
a = 6378245.0
ee = 0.00669342162296594323

unwrapper = (o) ->
  output = {}
  for k, v of o
    if typeof v == 'object'
      x = unwrapper(v)
      for k2, v2 of x
        output["#{k}.#{k2}"] = v2
    else
      output[k] = v
  return output

jade2pdf = (jade_filename, locals, pdf_filename) ->
  new Promise (rs, rj) ->
    fn = jade.compileFile jade_filename, {}
    html = fn locals

    wkhtmltopdf html, output: pdf_filename, (err) ->
      if err?
        return rj err
      rs pdf_filename

utils =
  randomToken: (len=8) ->
    chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    charlen = chars.length
    getRandomInt = (min, max) ->
        Math.floor(Math.random() * (max - min + 1)) + min
    ([0...len].map () -> chars[getRandomInt(0, charlen - 1)]).join("")

  moveUploadedFile: Promise.method (obj, dest, make_thumb = true, crop_to_square = true) ->
    # obj validation check
    if obj? && typeof obj == 'string' # path를 바로 넘겨준것
      path = obj
      return path.resolve RootPath, obj

    if !(obj? && obj.path? && obj.size? && obj.name? && obj.type? && obj.size > 0)
      logger.warn "moveUploadedFile - do nothing. 'obj' is not a file or have zero size"
      return null

    # multipart로 올라온 파일을 적절한 위치로 옮긴다.
    if dest?
      dir = path.dirname(dest)
      promise = Promise.promisify(mkdirp)(dir)
    else
      # 폴더 위치 및 파일 이름은 날짜를 기준으로 생성한다.
      # ex: 2014.7.27 14:21(unix timestamp: 1406438508)에
      # 올라온 파일이면 directory는 uploads/14/7/27/14/[randomhex]_1406438508.[ext]
      now = new Date()
      dir = path.join RootPath, "uploads", "#{now.getYear()-100}", "#{now.getMonth()+1}", "#{now.getDate()}", "#{now.getHours()}"
      dest = path.join dir, "#{utils.randomToken()}_#{now.getTime()}#{path.extname(obj.path)}"
      promise = if fs.existsSync(dir) then Promise.resolve() else Promise.promisify(mkdirp)(dir)

    promise.then () ->
      Promise.promisify(fs.readFile)(obj.path)
    .then (data) ->
      logger.info "file upload path='#{dest}'"
      Promise.promisify(fs.writeFile)(dest, data)
    .then () ->
      # create background job
      ext = path.extname dest
      if make_thumb and ext in [".jpg", ".png", ".gif", ".jpeg"]
        ext = path.extname(dest)
        basename = path.basename(dest, ext)
        dirname = path.dirname(dest)
        thumb_dst = path.join(dirname, "#{basename}_t#{ext}")
        #logger.verbose "thumb_dst=#{thumb_dst}"
        easyimg.resize(src: dest, dst: thumb_dst, width: 100, height: 100)
        .then (img) ->
          logger.info "thumb img created"
          return path.sep + (path.relative RootPath, dest)
      else
        path.sep + (path.relative RootPath, dest)

  makeArray: (thing) ->
    if thing?
      if thing instanceof Array
        merged = []
        merged.concat.apply merged, thing
      else
        [thing]
    else
      []

  encrypt: (plain_string, key_base64) ->
    #console.log "plain_string=#{plain_string}"
    #console.log "key_base64=#{key_base64}"
    cipher = crypto.createCipher('des-ede3-cbc', new Buffer(key_base64, "base64"))
    cryptedPassword = cipher.update(plain_string, 'utf8', "base64")
    cryptedPassword+= cipher.final("base64")
    return cryptedPassword

  decrypt: (crypted_string, key_base64) ->
    decipher = crypto.createDecipher('des-ede3-cbc', new Buffer(key_base64, "base64"))
    decryptedPassword = decipher.update(crypted_string, "base64", 'utf8')
    decryptedPassword += decipher.final('utf8')
    return decryptedPassword

  locale_norm: (locale) ->
    locale = locale.toLowerCase()
    # check Chinese (simplified)
    if locale.match(/hans/)? || locale.match(/cn/)?
      return "zh_hans"
    # check Chinese (traditional)
    else if locale.match(/hant/)?
      return "zh_hant"
    # check Chinese (others.. assume traditional)
    else if locale.match(/zh/)? || locale.match(/tw/)? || locale.match(/hk/)?
      return "zh_hant"
    # check Korean
    else if locale.match(/kr/)? || locale.match(/ko/)?
      return "ko"
    # check Japanese
    else if locale.match(/ja/)? || locale.match(/jp/)?
      return "ja"
    else
      return "en"

  # geocode: (pos) ->
    # epsilon = 0.0001
    # Models.GeoCode.find
      # where:
        # latitude:
          # $lte:
            # pos.latitude + epsilon
          # $gte:
            # pos.latitude - epsilon
        # longitude:
          # $lte:
            # pos.longitude + epsilon
          # $gte:
            # pos.longitude - epsilon
    # .then (geocode) ->
      # if geocode?
        # return geocode.result

      # url = "http://api.map.baidu.com/geocoder/v2/" +
            # "?ak=#{config.baidu.map.apiKey}" +
            # "&location=#{pos.latitude},#{pos.longitude}" +
            # "&output=json"
      # http_get url

  http_get: http_get
  https_get: https_get
  get_mobile_version: (ua, app_type) ->
    if app_type == "customer"
      if ua?.match(/iOS [\d.]+/)?
        os_ver = ua.match(/iOS [\d.]+/)?[0]
        app_ver = ua.match(/easiway-customer\/([\d.]+)/)?[1]
      else if ua?.indexOf("easiway.android") >= 0
        os_ver = ua.match(/Android [\d.]+/)?[0]
        app_ver = ua.match(/easiway\.android\/([\d.a-z]+)/)?[1]

      return "#{app_type};#{app_ver};#{os_ver}"
    else if app_type == "corporate"
      if ua?.match(/iOS [\d.]+/)?
        os_ver = ua.match(/iOS [\d.]+/)?[0]
        app_ver = ua.match(/easiway-corporate|easiwaycorp\/([\d.]+)/)?[1]
      else if ua?.indexOf("easiwaycorp.android") >= 0
        os_ver = ua.match(/Android [\d.]+/)?[0]
        app_ver = ua.match(/easiwaycorp\.android\/([\d.a-z]+)/)?[1]

      return "#{app_type};#{app_ver};#{os_ver}"
    # else TODO implement

  send_mail: (user, title, tmpl_name, locals, attachments, bccs) ->
    job = jobs.create("easishare:mail",
      locals: locals
      target: user
      tmpl_name: tmpl_name
      title: title
      bccs: bccs || []
      attachments: attachments).removeOnComplete(true)
    mailjob = Promise.promisify job.save, job
    mailjob()
    .then ->
      logger.info "kue job '#{job.type}' created"

  wrap: (obj) ->
    pack = (o, sa, v) ->
      arr = false
      if sa[0] == '0' || parseInt(sa[0])
        if Object.prototype.toString.call(o) != '[object Array]'
          arr = true
          o = []

      if sa.length == 1
        if arr
          o.push(v)
          return

        o[sa[0]] = v
        return

      if !o[sa[0]]
        if arr
          o.push({})
        else
          o[sa[0]] = {}

      d_sa = []

      for i in [1...sa.length]
        d_sa.push(sa[i])
      pack(o[sa[0]],d_sa,v)

    o = {}
    prop = []
    for k,v of obj
      prop = k.split('.')
      pack(o, prop, v)
    return o

  unwrap: unwrapper

  jade2pdf: jade2pdf

  parseBool: (str) ->
    if str == null
      return false

    if typeof str == 'boolean'
      return str

    if typeof str == 'string'
      if str == ""
        return false

      str = str.replace(/^\s+|\s+$/g, '')
      if str.toLowerCase() == 'true' || str.toLowerCase() == 'yes'
        return true

      str = str.replace(/,/g, '.')
      str = str.replace(/^\s*\-\s*/g, '-')

    if !isNaN(str)
      return parseFloat(str) != 0

    return false

  gen_upload_dir: ->
    new Promise (rs, rj) ->
      now = new Date
      dir_path = path.join RootPath, "uploads", "#{now.getYear()-100}", "#{now.getMonth()+1}",
        "#{now.getDate()}", "#{now.getHours()}"

      mkdirp dir_path, (err) ->
        return rj err if err?
        rs dir_path

  normalize_city_name: (city) ->
    city.replace(/^香港特别行政区/, '香港').replace(/市$/, "")

  locale2countryCode: (locale) ->
    switch locale
      when "en"
        "USA"
      when "ko"
        "KOR"
      when "zh_hant"
        "HKG"
      when "zh_hans"
        "CHN"
      when "ja"
        "JPN"
      else
        "USA"

  weeks_of_month: (year, month) ->
    month_start = moment("#{year}-#{month}-01")
    month_end = moment(month_start).endOf 'month'

    res = []

    start = moment(month_start)
    while start <= month_end
      weekend = moment(start).endOf 'isoWeek'
      if weekend > month_end
        weekend = month_end

      res.push [start.format("YYYY-MM-DD"),
                weekend.format("YYYY-MM-DD")]

      start = moment(weekend)
      start.add 1, "second"

    return res

  leading_slash: (str) ->
    unless str?
      return null
    if str.match(/^\//)?
      str
    else
      "/#{str}"

  is_email_format: (str) ->
    str.match(/[\w-]+@([\w-]+\.)+[\w-]+/)?

  path_by_time: (date, minsec=false) ->
    s = path.join "#{date.getYear()-100}", "#{date.getMonth()+1}", "#{date.getDate()}", "#{date.getHours()}"
    if minsec
      s = path.join s, "#{date.getMinutes()}#{date.getSeconds()}"
    return s


module.exports = utils

# vim: set ts=2 sw=2 :
