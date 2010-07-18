module Rack

  # A Rack middleware for providing JSON-P support.
  #
  # Full credit to Flinn Mueller (http://actsasflinn.com/) for this contribution.
  #
  class JSONP
    include Rack::Utils

    def initialize(app)
      @app = app
    end

    # Proxies the request to the application, stripping out the JSON-P callback
    # method and padding the response with the appropriate callback format if
    # the returned body is application/json
    #
    # Changes nothing if no <tt>callback</tt> param is specified.
    #
    def call(env)
      status, headers, response = @app.call(env)

      headers = HeaderHash.new(headers)
      request = Rack::Request.new(env)
      
      if is_json?(headers) && has_callback?(request)
        status, response = translate_error_code(status, response)
        response = pad(request.params.delete('callback'), response)

        # No longer json, its javascript!
        headers['Content-Type'].gsub!('json', 'javascript')
        
        # Set new Content-Length, if it was set before we mutated the response body
        if headers['Content-Length']
          length = response.to_ary.inject(0) { |len, part| len + bytesize(part) }
          headers['Content-Length'] = length.to_s
        end
      end
      [status, headers, response]
    end
    
    private
    
    def is_json?(headers)
      headers['Content-Type'].include?('application/json')
    rescue
      nil
    end
    
    def has_callback?(request)
      request.params.include?('callback')
    end

    # Pads the response with the appropriate callback format according to the
    # JSON-P spec/requirements.
    #
    # The Rack response spec indicates that it should be enumerable. The
    # method of combining all of the data into a single string makes sense
    # since JSON is returned as a full string.
    #
    def pad(callback, response, body = "")
      response.each{ |s| body << s.to_s }
      ["#{callback}(#{body})"]
    end
    
    # Translate status code 40x and 50x to a json string in response, and change
    # status code to 200. That because the jsonp's implemetation could not handler 
    # http status code when error occured, which could be meaningful in webservice.
    def translate_error_code(status, response)
      if status % 400 == 4 || status % 500 == 5
        [200, [%Q|{"errorCode":#{status}}|]]
      else
        [status, response]
      end
    end

  end
end
