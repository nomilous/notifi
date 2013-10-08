{hostname} = require 'os'
{deferred} = require 'also'
notifier   = require '../notifier'
Connector  = require './connector'
{
    terminal
    reservedCapsule
    undefinedArg
    alreadyDefined
    connectRejected
    disconnected
} = require '../errors'


testable               = undefined
module.exports._client = -> testable
module.exports.client  = (config = {}) ->

    for type of config.capsules

        throw reservedCapsule type if type.match(
            /^connect$|^handshake$|^accept$|^reject$|^disconnect$|^resume$|^capsule$|^nak$|^ack$|^error$/
        )


    testable = local = 

        Notifier: notifier.notifier config
        clients:  {}

        create: deferred ({reject, resolve, notify}, originName, opts = {}, callback) -> 
            
            try 

                throw undefinedArg 'originName' unless typeof originName is 'string'
                throw alreadyDefined 'originName', originName if local.clients[originName]?
                throw undefinedArg 'opts.connect.port' unless opts.connect? and typeof opts.connect.port is 'number'
                
                client = local.Notifier.create originName
                local.clients[originName] = client

            catch error

                return terminal error, reject, callback


            opts.context ||= {}
            opts.context.hostname = hostname()
            opts.context.pid      = process.pid


            socket = Connector.connect opts.connect

            client.connection       ||= {}
            client.connection.state   = 'pending'
            client.connection.stateAt = Date.now()
            already = false 


            #
            # #DUPLICATE1
            # 
            # subscribe inbound handlers for all configured capsules
            # ------------------------------------------------------
            # 
            # TODO: set capsule.inbound
            # 

            for type of config.capsules

                    #
                    # * control capsules are local only
                    #  

                continue if type == 'control'
                do (type) -> 

                    #
                    # * all other capsules are proxied into the local 
                    #   middleware pipeline (hub) 
                    #

                    socket.on type, (payload) -> 

                        unless typeof client[type] == 'function'

                            # 
                            # * client and hub should use a common capsules config
                            # 

                            process.stderr.write "notice undefined capsule type '#{type}'"
                            return

                        #
                        # * proxy the inbound capsules onto the middleware pipeline
                        # TODO: typeValue, protected, hidden, watched
                        # 

                        client[type] payload


            #
            # last middleware on the local bus transfers capsule onto socket 
            # --------------------------------------------------------------
            # 
            # * This only occurrs if the capsule reaches the end of the local 
            #   middleware pipeline.
            # 

            version  = 1    # protocol version
                            # TODO: version into handshake
            
            #
            # * The final middleware resolver for each capsule sent to the
            #   hub is placed into this transit collection pending certainty
            #   of handover to the hub. (ack)
            # 

            transit = {}

            client.use

                title: 'outbound socket interface'
                last:  true
                (next, capsule) -> 

                    ### grep PROTOCOL1 encode ###

                    #
                    # TODO: is socket connected?
                    #       what happens when sending on not 
                    #
                    # 
                    header = [version]

                    #
                    # TODO: much room for optimization here
                    # TODO: move this into {protocol}.encode
                    # 

                    control = 
                        type:      capsule._type
                        uuid:      capsule._uuid
                        protected: capsule._protected
                        hidden:    capsule._hidden

                    socket.emit 'capsule', header, control, capsule.all
                    
                    #
                    # TODO: transit collection needs limits set, it is conceivable
                    #       that an ongoing malfunction could guzzle serious memory
                    # TODO: using a fullblown uuid as key is possibly excessive?
                    # 

                    #
                    # * pend the final middleware resolver till either ack or nak
                    #   from the hub
                    #

                    transit[capsule._uuid] = next: next

                    # 
                    # * Send notification of the transmission to the promise notifier
                    #   waiting at the capsule origin.
                    #   
                    #   Unfortunately a capsule origin with a node style callback
                    #   waiting has no concrete facility to receive this information
                    #   and will remain in the dark until the hub ack / nak.
                    # 

                    process.nextTick -> next.notify
                        _type:   'control'
                        control: 'transmitted'
                        capsule: capsule


            socket.on 'ack', (control) -> 

                try 
                    {uuid} = control
                    {next} = transit[uuid]

                catch error
                    process.stderr.write 'notice: invalid or unexpected ack'
                    return

                #
                # * ack calls the next() that was pended in the final middleware
                #   at the time of sending the capsule to the hub.
                #

                next()



            socket.on 'nak', (control) -> 

                console.log nak: control



            socket.on 'connect', -> 
                if client.connection.state == 'interrupted'

                    #
                    # previously fully established connection has resumed
                    # ---------------------------------------------------
                    # 
                    # * It is possible the server still has reference to
                    #   this client context so this sends a resume event
                    #   but includes all handshake data incase the server
                    #   has lost all notion. 
                    #

                    client.connection.state   = 'resuming'
                    client.connection.stateAt = Date.now()
                    socket.emit 'resume', originName, opts.connect.secret || '', opts.context || {}

                    #
                    # * server will respond with 'accept' on success, or disconnect()
                    #

                    #
                    # TODO: inform resumed onto the local middleware 
                    #

                    return

                client.connection.state   = 'connecting'
                client.connection.stateAt = Date.now()
                socket.emit 'handshake', originName, opts.connect.secret || '', opts.context || {}

                #
                # * server will respond with 'accept' on success, or disconnect()
                #


            socket.on 'accept', -> 
                if client.connection.state == 'resuming'

                    #
                    # the resuming client has been accepted
                    # -------------------------------------
                    # 
                    # * This does not callback with the newly connected client,
                    #   that callback only occurs on the first connect
                    #

                    #
                    # TODO: inform resumed onto the local middleware 
                    # TODO: hub context
                    # 

                    client.connection.state   = 'accepted'
                    client.connection.stateAt = Date.now()
                    client.connection.interruptions ||= count: 0
                    client.connection.interruptions.count++
                    return 

                #
                # TODO: hub context
                # 

                client.connection.state   = 'accepted'
                client.connection.stateAt = Date.now()
                resolve client
                if typeof callback == 'function' then callback null, client


            socket.on 'reject', (rejection) -> 

                ### it may happen that the disconnect occurs before the reject, making the rejection reason 'vanish' ###

                terminal connectRejected(originName, rejection), reject, callback
                already = true

            socket.on 'disconnect', -> 
                unless client.connection.state == 'accepted'

                    #
                    # the connection was never fully established
                    # ------------------------------------------
                    #
                    # TODO: notifier.destroy originName (another one in on 'error' below)
                    #       (it will still be present in the collection there)
                    #
                    # TODO: formalize errors 
                    #       (this following is horrible)
                    # 

                    delete local.clients[originName]
                    terminal disconnected(originName), reject, callback unless already
                    already = true
                    return 
                
                #
                # fully established connection has been lost
                # ------------------------------------------
                #

                client.connection.state   = 'interrupted'
                client.connection.stateAt = Date.now()
                return

                #
                # TODO: inform interrupted onto the local middleware 
                #



            socket.on 'error', (error) -> 
                unless client.connection? and client.connection.state == 'pending'
                    
                    #
                    # TODO: handle error after connect|accept
                    #

                    console.log 'TODO: handle socket error after connect|accept'
                    console.log error
                    return


                delete local.clients[originName]
                setTimeout (-> 

                    # 
                    # `opts.connect.errorWait`
                    # 
                    # * Incase something is managing the process that exited because no 
                    #   connection was made in such a way that it enters a tight respawn 
                    #   loop effectively creating a potentially dangerous SYN flood
                    # 

                    reject error
                    if typeof callback == 'function' 
                        callback error unless already
                        already = true

                ), opts.connect.errorWait or 2000
                return

                # #
                # # `opts.connect.retryWait`
                # # 
                # # * OVERRIDES `opts.connect.errorWait`
                # # 
                # # * Incase it is preferrable for the connection to be retried indefinately
                # # * IMPORTANT: The callback only occurs after connection, so this will leave
                # #              the caller of Notice.client waiting... (possibly a long time)
                # # * RECOMMEND: Do not using this in high frequency scheduled jobs.
                # # 

                # if opts.connect.retryWait? # and opts.connect.retryWait > 9999

                #     client.connection.state            = 'retrying'
                #     client.connection.retryStartedAt ||= Date.now()
                #     client.connection.retryCount      ?= -1
                #     client.connection.retryCount++
                #     client.connection.stateAt          = Date.now()
                #     console.log RETRY: client.connection
                #     return


                # opts.connect.retryWait = 0 # ignore crazy retryWait milliseconds
                # error = new Error "Client.create( '#{originName}', opts ) failed connect"
                # reject error
                # if typeof callback == 'function' then callback error



            


    return api = 
        create: local.create

