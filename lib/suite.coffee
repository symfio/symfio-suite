callbacks = require "when/callbacks"
methods = require "methods"
sinon = require "sinon"
chai = require "chai"
w = require "when"


chai.use require "chai-as-promised"
chai.use require "chai-http"
chai.use require "sinon-chai"
chai.should()


suitePlugin = (container) ->
  container.set "env", "test"
  container.set "chai", chai
  container.set "sinon", sinon

  container.set "request", (app, chai) ->
    chaiRequest = chai.request app
    request = {}

    methods.forEach (method) ->
      method = "del" if method is "delete"

      request[method] = ->
        req = chaiRequest[method].apply chaiRequest, arguments
        req.then = ->
          callbacks.call(req.res.bind req).then.apply null, arguments
        req

    request

  container.set "sandbox", (sinon) ->
    sinon.sandbox.create()

  container.set "logger", (sandbox) ->
    silly: sandbox.spy()
    debug: sandbox.spy()
    verbose: sandbox.spy()
    info: sandbox.spy()
    warn: sandbox.spy()
    error: sandbox.spy()

  container.set "promise", (sinon) ->
    promise = then: sandbox.stub()
    promise.then.yields()
    promise

  container.set "containerStub", (sandbox, promise) ->
    containerStub =
      set: sandbox.stub()
      has: sandbox.stub()
      unless: sandbox.stub()
      get: sandbox.stub()
      inject: sandbox.stub()

    containerStub.set.get = (key) ->
      call = containerStub.set.withArgs key
      call.should.be.calledOnce
      call.firstCall.args[1]

    containerStub.unless.get = (key) ->
      call = containerStub.unless.withArgs key
      call.should.be.calledOnce
      call.firstCall.args[1]

    containerStub.inject.get = (num) ->
      containerStub.inject.callCount.should.be.above num
      call = containerStub.inject.getCall num
      call.args[0]

    containerStub.inject.returns promise
    containerStub


wrappedIt = (message, test) ->
  it message, (callback) ->
    suite.container.inject(test).should.notify callback

wrappedIt.only = (message, test) ->
  it.only message, (callback) ->
    suite.container.inject(test).should.notify callback

wrappedIt.skip = it.skip


module.exports = suite =
  ###
  if __dirname is "/symfio-contrib-plugin/node_modules/symfio-suite/lib"
  then require "/symfio-contrib-plugin/node_modules/symfio"
  ###
  symfio: require "../../symfio"

  example: (container) ->
    container.inject suitePlugin

    before (callback) ->
      @timeout 0
      container.promise.then ->
        suite.container = container
      .should.notify callback

    wrappedIt

  plugin: (plugins) ->
    beforeEach (callback) ->
      suite.container = module.exports.symfio "test", __dirname
      suite.container.inject suitePlugin
      suite.container.injectAll(plugins).should.notify callback

    afterEach (callback) ->
      suite.container.inject (sandbox) ->
        sandbox.restore()
      .should.notify callback

    wrappedIt
