validate = (arrayOfMiddleware) -> 

    return arrayOfMiddleware

module.exports = -> 
    
    try

        #
        # users can define HOME/.notice/middleware.js
        #

        middleware = require "#{  process.env.HOME  }/.notice/middleware"
        processed  = {}

        if middleware.all? 

            processed.all = middleware.all

        for key of middleware

            continue if key == 'all'

            processed[key] = 

                if typeof middleware[key] == 'function'

                    matchAll: origin: key
                    fn: middleware[key]

                else if middleware[key] instanceof Array

                    validate middleware[key]

                else

                    undefined

        return processed


    catch error

        #
        # if they want to
        #

        {}
