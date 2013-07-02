require('nez').realize 'Client', (Client, test, context, Connector, Notifier, Message) -> 

    context 'connect()', (it) ->

        it 'makes a connection', (done) ->

            Connector.connect = (opts, callback) -> 

                opts.should.eql 
                    loglevel: undefined
                    secret: undefined
                    transport: 'https'
                    address: 'localhost'
                    port: 10001 

                test done


            Client.connect 'title', 

                connect:
                    transport: 'https'
                    address: 'localhost'
                    port: 10001

                (error, client) -> 


    context 'onConnect()', (it) -> 

        EMITTED = {}
        SOCKET  = 
            emit: (event, args...) -> EMITTED[event] = args
            on: (event, callback) -> 
        NOTICE  = {}
        Connector.connect = (opts, callback) -> callback null, SOCKET
        Notifier.create = (title) -> NOTICE.title = title; return NOTICE


        it 'creates a notifier', (done) -> 

            Client.connect 'title',

                connect:
                    transport: 'https'
                    address: 'localhost'
                    port: 10001

                (error, notice) -> 

                    notice.title.should.equal 'title'
                    test done


        it 'assigns final middleware to notifier', (done) -> 

            Client.connect 'title',

                connect:
                    transport: 'https'
                    address: 'localhost'
                    port: 10001

                (error, notice) -> 

                    notice.last.should.be.an.instanceof Function
                    test done


        it 'emits outbound notifications onto the socket', (done) -> 

            EMITTED.info = []

            Client.connect 'title',

                connect:

                    transport: 'https'
                    address: 'localhost'
                    port: 10001

                (error, notice) -> 

                    #
                    # asif the notifier itself called the middleware
                    #

                    notice.last(

                        new Message

                            #
                            # context
                            # 

                            title: 'title'
                            description: 'description'
                            origin: 'origin'
                            type: 'info'
                            tenor: 'normal'
                            direction: 'out'

                            #
                            # payload
                            #

                            key1: 'value1'
                            key2: 'value2'           

                        ->

                           

                            #
                            # context as event arg1
                            #  

                            EMITTED.info[0].should.eql

                                title: 'title'
                                description: 'description'
                                origin: 'origin'
                                type: 'info'
                                tenor: 'normal'
                                direction: 'out'

                            #
                            # payload as event arg1
                            #  

                            EMITTED.info[1].key1.should.eql 'value1'
                            EMITTED.info[1].key2.should.eql 'value2'
                            test done

                    )

        it 'does not emit notifications onto the socket if they are not outbound', (done) -> 

            EMITTED.info = []

            Client.connect 'title',

                connect:

                    transport: 'https'
                    address: 'localhost'
                    port: 10001

                (error, notice) -> 

                    notice.last(

                        new Message
                            title: 'title'
                            description: 'description'
                            origin: 'origin'
                            type: 'info'
                            tenor: 'normal'
                            direction: 'in'         

                        ->

                            EMITTED.info.length.should.equal 0
                            test done
                    )