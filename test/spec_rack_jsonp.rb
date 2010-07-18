require 'test/spec'
require 'rack/mock'
require File.expand_path(File.dirname(__FILE__)+"/../lib/rack/contrib/jsonp")

context "Rack::JSONP" do

  context "when a callback parameter is provided" do
    specify "should wrap the response body in the Javascript callback if JSON" do
      test_body = '{"bar":"foo"}'
      callback = 'foo'
      app = lambda { |env| [200, {'Content-Type' => 'application/json'}, [test_body]] }
      request = Rack::MockRequest.env_for("/", :params => "foo=bar&callback=#{callback}")
      body = Rack::JSONP.new(app).call(request).last
      body.should == ["#{callback}(#{test_body})"]
    end
    
    specify "should not wrap the response body in a callback if body is not JSON" do
      test_body = '{"bar":"foo"}'
      callback = 'foo'
      app = lambda { |env| [200, {'Content-Type' => 'text/plain'}, [test_body]] }
      request = Rack::MockRequest.env_for("/", :params => "foo=bar&callback=#{callback}")
      body = Rack::JSONP.new(app).call(request).last
      body.should == ['{"bar":"foo"}']
    end
    
    specify "should update content length if it was set" do
      test_body = '{"bar":"foo"}'
      callback = 'foo'
      app = lambda { |env| [200, {'Content-Type' => 'application/json', 'Content-Length' => test_body.length}, [test_body]] }
      request = Rack::MockRequest.env_for("/", :params => "foo=bar&callback=#{callback}")

      headers = Rack::JSONP.new(app).call(request)[1]
      expected_length = test_body.length + callback.length + "()".length
      headers['Content-Length'].should == (expected_length.to_s)
    end
    
    specify "should not touch content length if not set" do
      test_body = '{"bar":"foo"}'
      callback = 'foo'
      app = lambda { |env| [200, {'Content-Type' => 'application/json'}, [test_body]] }
      request = Rack::MockRequest.env_for("/", :params => "foo=bar&callback=#{callback}")
      headers = Rack::JSONP.new(app).call(request)[1]
      headers['Content-Length'].should be_nil
    end
    
    specify "should modify the content type to application/javascript" do
      test_body = '{"bar":"foo"}'
      callback = 'foo'
      app = lambda { |env| [200, {'Content-Type' => 'application/json'}, [test_body]] }
      request = Rack::MockRequest.env_for("/", :params => "foo=bar&callback=#{callback}")
      headers = Rack::JSONP.new(app).call(request)[1]
      headers['Content-Type'].should == ('application/javascript')
    end
    
    specify "should write status code to body and set status to 200 if status is 40x or 50x" do
      callback = 'foo'
      app = lambda { |env| [404, {'Content-Type' => 'application/json'}, [""]] }
      request = Rack::MockRequest.env_for("/", :params => "foo=bar&callback=#{callback}")
      status, headers, body = Rack::JSONP.new(app).call(request)
      status.should == 200
      body.should == ["#{callback}({\"errorCode\":404})"]
    end
    
  end

  specify "should not change anything if no callback param is provided" do
    test_body = ['{"bar":"foo"}']
    app = lambda { |env| [200, {'Content-Type' => 'application/json'}, test_body] }
    request = Rack::MockRequest.env_for("/", :params => "foo=bar")
    body = Rack::JSONP.new(app).call(request).last
    body.should == test_body
  end

  specify "should not change anything if it's not a json response" do
    test_body = '<html><body>404 Not Found</body></html>'
    app = lambda { |env| [404, {'Content-Type' => 'text/html'}, [test_body]] }
    request = Rack::MockRequest.env_for("/", :params => "callback=foo", 'HTTP_ACCEPT' => 'application/json')
    body = Rack::JSONP.new(app).call(request).last
    body.should == [test_body]
  end

end