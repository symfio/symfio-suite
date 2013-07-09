symfio = require "../../symfio"
chai = require "chai"


chai.use require "chai-as-promised"
chai.use require "chai-http"
chai.use require "sinon-chai"
chai.should()


wrapIt = ->
  wrappedIt = (message, dependencies, test) ->
    it message, (callback) ->
      wrapIt.container.inject(dependencies, test).should.notify callback

  wrappedIt.only = (message, dependencies, test) ->
    it.only message, (callback) ->
      wrapIt.container.inject(dependencies, test).should.notify callback

  wrappedIt.skip = it.skip
  wrappedIt


module.exports = suite = (container) ->
  container.set "env", "test"
  container.require require
  container.require "chai"
  container.require "methods"
  container.require "when/callbacks"
  container.set "sinon", require "sinon"
  
  container.set "suite/parseArguments", ->
    (fun) ->
      fun.toString()
        .match(/function\s+\w*\s*\((.*?)\)/)[1]
        .split(/\s*,\s*/)
        .filter((arg) -> arg.length > 0)

  container.set "suite/factory",
    ["suite/parseArguments", "w"],
    (parseArguments, w) ->
      (dependencies, factory) ->
        if factory is undefined
          factory = dependencies
          dependencies = parseArguments factory

        factoryStub = ->
          tasks = dependencies.map (dependency) ->
            if factoryStub.dependencies.hasOwnProperty dependency
              factoryStub.dependencies[dependency]
            else
              container.get dependency

          w.all(tasks).then (args) ->
            for i in [0...args.length]
              factoryStub.dependencies[dependencies[i]] = args[i]
            factoryStub.args = args
            factory.apply null, args

        factoryStub.dependencies = {}
        factoryStub

  container.set "request",
    ["app", "chai", "methods", "when/callbacks"],
    (app, chai, methods, callbacks) ->
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

  container.set "sandbox",
    (sinon) ->
      sinon.sandbox.create()

  container.set "logger",
    (sandbox) ->
      silly: sandbox.spy()
      debug: sandbox.spy()
      verbose: sandbox.spy()
      info: sandbox.spy()
      warn: sandbox.spy()
      error: sandbox.spy()

  container.set "stub",
    (container) ->
      setFunction: (key) ->
        container.set key, (sandbox) ->
          sandbox.stub()

      setPromisedFunction: (key, value) ->
        container.set key, (sandbox, w) ->
          stub = sandbox.stub()
          stub.returns w.resolve value
          stub

  container.set "suite/container",
    (sandbox) ->
      containerStub =
        set: sandbox.stub()
        has: sandbox.stub()
        unless: sandbox.stub()
        get: sandbox.stub()
        inject: sandbox.stub()
        require: sandbox.stub()
      containerStub.get.promise = then: sandbox.stub()
      containerStub.get.returns containerStub.get.promise
      containerStub.inject.promise = then: sandbox.stub()
      containerStub.inject.returns containerStub.inject.promise
      containerStub

  container.set "setted",
    ["suite/container", "suite/factory"],
    (container, factory) ->
      (key) ->
        call = container.set.withArgs key
        call.should.be.calledOnce
        factory call.firstCall.args[1], call.firstCall.args[2]

  container.set "unlessed",
    ["suite/container", "suite/factory"],
    (container, factory) ->
      (key) ->
        call = container.unless.withArgs key
        call.should.be.calledOnce
        factory call.firstCall.args[1], call.firstCall.args[2]

  container.set "injected",
    ["suite/container", "suite/factory"],
    (container, factory) ->
      (num = 0) ->
        container.inject.callCount.should.be.above num
        call = container.inject.getCall num
        factory call.args[0], call.args[1]


suite.example = (container) ->
  container.inject suite

  before (callback) ->
    @timeout 0
    container.promise.should.notify callback

  wrapIt.container = container
  wrapIt()


suite.plugin = (plugin) ->
  beforeEach (callback) =>
    wrapIt.container = symfio "test", __dirname
    wrapIt.container.injectAll([
      suite
      plugin
    ]).should.notify callback

  afterEach (callback) =>
    wrapIt.container.inject (sandbox) ->
      sandbox.restore()
    .should.notify callback

  wrapIt()
