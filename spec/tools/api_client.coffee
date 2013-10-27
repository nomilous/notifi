{Client}       = require 'dinkum'
exports.client = Client.create
    transport: 'http'
    port: 3333
    authenticator:
        module: 'basic_auth'
        username: 'Api Client Username'
        password: '∆'
    content:
        #
        # a custom media to encode the middleware
        #
        customMedia1: 
            encode: (req) -> 
                object = req.customMedia1
                fn = object.fn
                object.fn = '__SUBSTITUTE_THE_FUNCTION__'
                body = JSON.stringify object
                body = body.replace /\"__SUBSTITUTE_THE_FUNCTION__\"/, fn.toString()
                req.body = body
                req.headers ||= {}  # todo: dinkum does this
                req.headers['content-type'] = 'text/javascript'
