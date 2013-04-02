browser = require "zombie"
sinon = require "sinon"
chai = require "chai"


module.exports.http = (container) ->
  chai.use require "chai-http"
  suite = expect: chai.expect

  container.set "silent", true

  before (callback) ->
    @timeout 10000

    loader = container.get "loader"

    loader.once "loaded", ->
      suite.http = chai.request container.get "app"
      callback()

    loader.load()

  after (callback) ->
    @timeout 10000

    unloader = container.get "unloader"
    unloader.once "unloaded", callback
    unloader.unload()

  wrapper(suite)


module.exports.browser = (container) ->
  suite =
    expect: chai.expect
    assert: chai.assert

  container.set "silent", true

  before (callback) ->
    @timeout 10000

    loader = container.get "loader"

    loader.once "loaded", ->
      suite.browser = new browser
      suite.browser.site = "http://localhost:#{container.get 'port'}"
      callback()

    loader.load()

  after (callback) ->
    @timeout 10000

    unloader = container.get "unloader"
    unloader.once "unloaded", callback
    unloader.unload()

  wrapper(suite)


module.exports.sandbox = (symfio, configurator) ->
  chai.use require "sinon-chai"
  suite = expect: chai.expect

  beforeEach ->
    suite.sandbox = sinon.sandbox.create()
    containerConfigurator.call suite, symfio
    configurator.call suite

  afterEach ->
    suite.sandbox.restore()

  wrapper(suite)


wrapper = (suite) ->
  (test) ->
    (callback) ->
      if test.length > 0
        test.call suite, callback
      else
        test.call suite
        callback()


containerConfigurator = (symfio) ->
  @container = symfio.container()

  @container.set "name", "symfio"
  @container.set "silent", true

  @sandbox.stub symfio.logger.Logger.prototype
  @logger = new symfio.logger.Logger
  @container.set "logger", @logger

  @sandbox.stub symfio.loader.Loader.prototype
  @loader = new symfio.loader.Loader
  @container.set "loader", @loader

  @sandbox.stub symfio.unloader.Unloader.prototype
  @unloader = new symfio.unloader.Unloader
  @container.set "unloader", @unloader
