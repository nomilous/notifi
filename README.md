`npm install notice`

### Version 0.0.11

**unstable** - api changes almost certainly will occur (without deprecation warnings)

notice
======

A middleware based communications scaffold.


The Standalone Notifier
-----------------------

Implementes a MessageBus for communications confined to a single process.

### create an event notifier (the default)

```coffee

notice   = require 'notice'
notifier = notice.create 'origin name'

```
#### send an event
```coffee

notifier.event 'event name', { payload: 'data' }

#
# Send an event and assign a callback to receive the result.
#

notifier.event 'event name', { payload: 'data' }, (err, capsule) -> 
    
    #
    # * The `capsule` object is created from the emitted message
    #   and sent into the middleware pipeline.
    # 
    # * This callback receives the `capsule` if it successfully 
    #   traversed the middleware pipeline to it's end. 
    #  
    #   ie. All middleware called `next()`
    #
    # * Middleware traversal is terminated upon the first throw 
    #   or uncaught exception inside the pipeline and the `err` 
    #   is passed here.
    # 

```
#### register some middleware
```coffee

notifier.use title: 'assembly step 1', (next, msg) -> 
    
    msg.myContribution = '∑'
    next()

    #
    # why Middleware ?
    # ----------------
    # 
    # * The combination of subscribe-ability and assembly-line
    #   creates a powerful tool.
    # 

notifier.use title: 'Pie Thrower', (next, msg) -> 
    
    throw 'π'

    #
    # why a Title ? 
    # -------------
    # 
    # * The (not yet implemented) bottleneck identifiability.
    # 

```
#### send with a promise waiting instead of a callback
```coffee

notifier.event 'event name',

    sending:   'this message'
    with:      'a promise waiting'
    insteadOf: 'a node style callback waiting'
    for:       'the finalMessage'

.then(

    (capsule) -> # after the middleware
    (error)   -> console.log error == 'π'

)

```


### create a notifier that does more than just 'event()'

```coffee
os         = require 'os'
notice     = require 'notice'

{hostname, uptime, loadavg, totalmem, freemem} = os

module.exports.MessageBus = notice
    
    messages:

        #
        # creates a messageType called alert
        # notifier.alert( .. ).then( ... )
        #

        alert: 
            beforeCreate: (done, alert) -> 
                alert.sourceInfo = 
                    hostname: hostname()
                    uptime: uptime()
                    loadavg: loadavg()
                    totalmem: totalmem()
                    freemem: freemem()
                done()
            afterCreate:  (done, alert) -> 

                #
                # * This fires before the message is pushed onto the
                #   middleware pipeline.
                # 
                # * It creates an opportunity to pre-store the message
                #   and therefore have the persistence id/ref/uuid
                #   already assigned before emitting into runtime.
                # 

                alert.set
                    state: 'new'
                    watched: (change) -> 

                        # 
                        # * this callback fires if any middleware
                        #   update the state property
                        #
                        #   eg. alert.state = 'prioritized'
                        #     
                        #   change ==
                        #      property: 'state' 
                        #      from:     'new'
                        #      to:       'prioritized'
                        #      msg:      # as it is NOW! (including subsequent changes)
                        # 

```
#### use it
```coffee

{MessageBus} = require 'the_previous_block'

notifier = MessageBus.create 'origin_app_name'
notifier.alert "darn, i thought this wouldn't happen", 
    
    says: 'the developer'
    heresWhatIKnow: """ 

        Recorded at the time of writing the code. 

    """

```


The Distributable Notifier
==========================


The Hub
-------

`Notice.listen(hubName, opts, callback)`

```coffee

Notice.listen 'Hub Name', 

    #
    # Configure with opts.listen
    # -------------------------- 
    # 
    #  * Using socket.io
    #  * PENDING: adaptor abstraction to enable transport plugins
    #

    listen:

        secret:   '◊'
        port:     10101
        address:  '0.0.0.0'
        cert:   __dirname + '/cert/develop-cert.pem'
        key:    __dirname + '/cert/develop-key.pem'


    #
    # Callback receives listening hub
    # -------------------------------
    # 
    # * hub is the interface to remote notifiers
    # * ... precise api design still in progress
    #

    (error, hub) -> 

        throw error if error?

        #
        # assign middleware to handle arriving messages
        #

        ...


```



The Client
----------

`Notice.connect(clientName, opts, callback)`

```coffee

Notice.connect 'Client Name',
        
    connect:

        secret:      '◊'
        port:       10101
        transport: 'https'
    
    (error, client) -> 

        throw error if error?

        #
        # assign middleware to process messages
        # -------------------------------------
        # 
        # * client has only one middleware pipeline
        # * messages define context.direction (in|out)
        #   to distinguish between inbound an outbound 
        #   messages
        #

        ...


        #
        # send an event message
        #

        ...


```


The Future
==========

### possible features / general intensions

* persistability - capsule.save() and .refresh() 
* hub can uplink (as client) onto parent hub
* each hub's middleware has access to all hubs (including uplink) for message swtching
* msg.expectReply (resolves, callsback only after remote response, complexities in the case of broadcasts)
* named middleware (can be removed from the pipeline)
* flood protection
* time in pipeline / backlog (introspection)
* mobile APIs (systems are more commonly composed **of people** than software)


