listen = require './listen'

module.exports.create = (hubName, opts, callback) -> 
    
    unless typeof hubName is 'string' 

        throw new Error 'Notifier.listen( hubName, opts ) requires hubName as string'

    opts ||= {}
    hub  = socket: {}, context: {}
    io = listen opts, (error, address) -> 

        callback error, address if typeof callback == 'function'

            


    io.on 'connection', (socket) -> 



        socket.on 'handshake', (secret, context) -> 

            if secret == opts.secret

                hub.socket[  socket.id ] = socket
                hub.context[ socket.id ] = context

            else 

                socket.disconnect()




        socket.on 'disconnect', -> 

    
    return hub
