
module.exports = (grunt) ->
  grunt.registerMultiTask "e2e", "Run e2e tests in Karma test runner.", ->
    config = require "karma/lib/config"
    karma = require "karma"
    path = require "path"
    done = @async()
    
    adapterDir = path.join path.dirname(require.resolve "karma")
      , "..", "adapter"

    files = [
      "#{adapterDir}/lib/angular-scenario.js",
      "#{adapterDir}/angular-scenario.js"
    ]
    files.push @data if typeof @data is "string"
    files.concat @data if Array.isArray @data

    options = @options singleRun: true, urlRoot: "/root/"

    unless options.container
      grunt.log.error "Container not configured for run tests"
      return done false

    container = require path.join process.cwd(), options.container
    loader = container.get "loader"

    loader.once "loaded", =>
      configs = config.parseConfig false, options
      configs.proxies["/"] = "http://localhost:#{container.get 'port'}/"
      configs.files = files.concat configs.files
      setTimeout ->
        karma.server.start configs, done
      1000

    loader.load()
