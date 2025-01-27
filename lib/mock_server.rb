require "sinatra/base"
require "puma"
require "rack/handler/puma"
require "socket"
require "logger"

Thread.abort_on_exception = true

class MockServer
  class App < Sinatra::Base
    use Rack::ShowExceptions
  end

  def initialize(app, host: "0.0.0.0", port: 4000, &block)
    @app = app
    @host = host
    @port = port
  end

  def start
    @thread = Thread.new do
      Rack::Handler::Puma.run(@app, {
        :Host => @host, :Port => @port, :Silent => true, :AccessLog => []
      }) {|server| @server = server}
    end

    wait_for_service(@host, @port)

    self
  end

  def stop
    @server.stop

    wait_for_shutdown(@host, @port)

    self
  end

  module Methods
    def mock_server(**args, &block)
      app = Class.new(Sinatra::Base)
      app.class_eval(&block)
      @server = MockServer.new(app, **args, &block).start
    end
  end

protected
  def listening?(host, port)
    begin
      socket = TCPSocket.new(host, port)
      socket.close unless socket.nil?
      true
    rescue Errno::ECONNREFUSED,
      Errno::ECONNRESET,
      Errno::EBADF,           # Windows
      Errno::EADDRNOTAVAIL    # Windows
      false
    end
  end

  def wait_for_service(host, port, timeout = 10)
    start_time = Time.now

    until listening?(host, port)
      if timeout && (Time.now > (start_time + timeout))
        raise SocketError.new("Socket did not open within #{timeout} seconds")
      end
    end

    true
  end

  def wait_for_shutdown(host, port, timeout = 10)
    start_time = Time.now

    until !listening?(host, port)
      if timeout && (Time.now > (start_time + timeout))
        raise SocketError.new("Socket did not close within #{timeout} seconds")
      end
    end

    true
  end
end
