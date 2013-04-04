
module.exports = (grunt) ->
  grunt.registerMultiTask "karma", "Run tests in Karma test runner.", ->
    callback = @async()
    config = require "karma/lib/config"
    karma = require "karma"
    path = require "path"
    fs = require "fs"

    adapterDir = path.join path.dirname(require.resolve "karma")
      , "..", "adapter"

    adapters = []
    fs.readdirSync(adapterDir).forEach (file) ->
      adapters.push file.replace ".js", "" if file.indexOf(".js") > 0

    options = @options singleRun: true, urlRoot: "/root/"
    grunt.util._.extend options, @data.options if @data.options

    unless options.container
      grunt.log.error "Container not configured for run tests"
      return callback false

    unless options.adapter in adapters
      grunt.log.error "Adapter not configured or not found for run tests"
      return callback false

    files = [
      "#{adapterDir}/lib/#{options.adapter.toLowerCase()}.js"
      "#{adapterDir}/#{options.adapter.toLowerCase()}.js"
      path.join __dirname, "..", "node_modules", "chai", "chai.js"
    ]
    Array::push.apply files, @filesSrc

    container = require path.join process.cwd(), options.container
    unloader = container.get "unloader"
    loader = container.get "loader"

    loader.once "loaded", =>
      configs = config.parseConfig false, options
      configs.proxies["/"] = "http://localhost:#{container.get "port"}/"
      configs.files = files

      # Timeout for running http server
      # TODO: Create starting event in contrib-express
      setTimeout ->
        karma.server.start configs, -> unloader.unload()
      1000

    unloader.register ->
      callback()

    loader.load()
