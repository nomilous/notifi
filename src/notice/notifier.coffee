{pipeline, deferred} = require 'also'
{message}  = require './capsule/message'
{undefinedArg} = require './errors'

testable                 = undefined
module.exports._notifier = -> testable
module.exports.notifier  = (config = {}) ->

    #
    # create default capsule emitter if none defined
    #

    config.capsules = event: {} unless config.capsules?

    #
    # for builtin control capsules
    #

    config.capsules.control = {}

    testable = local = 

        capsuleTypes: {}
        middleware:   {}
        notifiers:    {}

        create: (originCode) ->
        
            throw new Error( 
                'Notifier.create(originCode) requires originCode as string'
            ) unless typeof originCode is 'string'

            throw new Error(
                "Notifier.create('#{originCode}') is already defined"
            ) if local.middleware[originCode]?

            
            middlewareCount = 0
            local.middleware[originCode] = list = {}
            final = undefined

            traverse = (capsule) -> 

                #
                # sends the capsule down the middleware pipeline
                # 

                return capsule unless middlewareCount || final? # no middleware
                middleware = for title of list
                    do (title) -> 
                        deferred ({resolve, reject, notify}) -> 

                            #
                            # TODO: (possibly)
                            #
                            # * coherently facilitate transactionality.
                            # 
                            #    eg. if 3rd middleware fails then something 
                            #        might like the opportunity to undo stuff
                            #        that the 1st and 2nd middleware did.
                            # 
                            # * handle middleware that never calls next()
                            #   or at least have queryable tracked traversal 
                            #   state and 'time in middleware' to identify 
                            #   such.
                            # 

                            next = -> process.nextTick -> resolve capsule

                            # TODO_LINK
                            next.info   = 'https://github.com/nomilous/notice/tree/develop/spec/notice#the-next-function'
                            next.notify = (update) -> process.nextTick -> notify update

                            try list[title] next, capsule   #, hubs
                                                                            #
                                                                            # TODO: consider enabling access to 
                                                                            #       all hubs in this process for 
                                                                            #       the middleware handlers to
                                                                            #       switch / route capsules.
                                                                            # 
                            catch error
                                reject error

                middleware.push(
                    deferred ({resolve, reject, notify}) -> 
                        
                        next = -> process.nextTick -> resolve capsule
                        next.notify = (update) -> process.nextTick -> notify update

                        try final next, capsule
                        catch error
                            reject error
                
                ) if final?

                return pipeline middleware

            local.notifiers[originCode] = notifier = 

                use: (opts, fn) -> 

                    throw undefinedArg( 
                        'opts.title and fn', 'use(opts, middlewareFn)'
                    ) unless ( 
                        opts? and opts.title? and 
                        fn? and typeof fn == 'function'
                    )

                    unless list[opts.title]?

                        list[opts.title] = fn
                        middlewareCount++
                        return

                    process.stderr.write "notice: middleware '#{originCode}' already exists, use the force()"

                force: (opts, fn) ->

                    throw undefinedArg( 
                        'opts.title and fn', 'use(opts, middlewareFn)'
                    ) unless ( 
                        opts? and opts.title? and 
                        ( fn? and typeof fn == 'function' ) or
                        ( opts.delete? and opts.delete is true )
                    )

                    if opts.delete and list[opts.title]?
                        delete list[opts.title]
                        middlewareCount++
                        return
                    
                    middlewareCount++ unless list[opts.title]?
                    list[opts.title] = fn

                final: (opts, fn) -> 

                    #
                    # assign a middleware to run last
                    # -------------------------------
                    # 
                    # * this can only be set once.
                    # * once set it cannot be changed
                    # 

                    if typeof final is 'function'
                        process.stderr.write "notice: final middleware cannot be reset! Not even using the force()"
                        return 

                    final = fn 

                    # 
                    # * used by the hub and client to 
                    #   transfer capsules from the bus
                    #   onto the network. 
                    # 






            #
            # create a function for each defined capsule type
            # -----------------------------------------------
            # 
            # * returns a promise that resolves with the capsule
            #   after it traversed all registered middleware
            # 
            # * if an error occurs on the pipeline the promise 
            #   is rejected and the remaining middlewares will
            #   not receive the capsule
            #

            for type of config.capsules
                continue if notifier[type]?
                do (type) -> 
                    notifier[type] = deferred (args...) -> 

                        {resolve, reject, notify} = args.shift()
                        payload = {}
                        
                        for arg in args
                            if (typeof arg).match /string|number/
                                if payload[type]? then payload.description = arg
                                else payload[type] = arg
                                continue
                            continue if arg instanceof Array # ignore arrays
                            for key of arg
                                continue if key == type and payload[key]?
                                payload[key] = arg[key] 
                        callback = arg if typeof arg == 'function'

                        return pipeline([
                            (       ) -> local.capsuleTypes[type].create payload
                            (capsule) -> traverse capsule

                        ]).then(
                            (capsule) -> 
                                resolve capsule
                                callback null, capsule if callback?
                            (err) -> 
                                reject err
                                callback err if callback?
                            notify
                        )
                        

            return notifier


    #
    # * create pre-defined capsule types
    #

    for type of config.capsules
        local.capsuleTypes[type] = message type, config


    return api = 

        create: local.create

