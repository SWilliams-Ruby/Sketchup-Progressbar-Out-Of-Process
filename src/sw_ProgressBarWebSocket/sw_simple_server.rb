# SW::ProgressBarWebSocket::Simple_server.server_stop
require 'cgi'
require 'socket'
  
module SW
  module ProgressBarWebSocket
    @suchat_connection_ID = 1000

    # A small webserver, call with http://localhost:48484/index.htm
    # This will obviously fail because of conflicting port numbers if run in two instances of sketchup
    #
    module Simple_server
      def self.server_loop()
        loop do
          @server_threads << Thread.start(@server.accept) do |tcpsocket|
            begin
              handle_request(tcpsocket)
              @server_threads.delete(Thread.current)  
            rescue => e
              server_log("Exception in Accept Thread: #{e.to_s}, #{e.backtrace.join("\n")}") 
            end  
          end
        end # end loop
        rescue => e
          server_log("Exception in Server Thread: #{e.to_s}, #{e.backtrace.join("\n")}") 
      end
      
      def self.handle_request(tcpsocket)
        request = ""
        while (line = tcpsocket.gets) && (line != "\r\n")
          request += line
        end

        request_uri, params = request.split(" ")[1].split("?")
        request_uri.sub!('html', 'htm') 
        params_hash = params ? CGI::parse(params) : {}

        # server_log("SW Simple Server: Request: #{request}")
        server_log("SW Simple Server: URI: #{request_uri}")
        # server_log("SW Simple Server: Params Hash: #{params_hash}")

        handler = @request_handlers[request_uri]
        if handler
          handler.call(tcpsocket, request)
        else
          response = "HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\nContent-Length:0\r\nConnection: close\r\n"
          tcpsocket.print response
          tcpsocket.close
        end
      end #server_loop
          
      ###############################33
      # Public Methods
      #
      def self.get_server
        self
      end
      
      # key is a URI string
      # meth is a method to called when URI is
      # requested by a browser.
      #
      def self.register_handler(key, meth)
        @request_handlers[key] = meth
      end
  
      ###############################33
      # Utility functions
      #
      def self.server_start()
        @server_start_time = Time.now
        server_stop if @server
        puts 'Starting SW Simple Server'
        @console_connected = false
        @console_rd_pipe, @console_wr_pipe = IO.pipe
        @request_handlers = {}
        add_default_request_handlers()

        @server = TCPServer.new('localhost', 48484)
        @server_thread = Thread.new {server_loop()}
        @server_thread.priority = 1
        @server_threads = []
      end
      
      def self.server_stop()
        puts 'Stopping SW Simple Server'
        begin
          @server_threads.each {|thr| thr.exit}
          @server_thread.exit
          @server.close if @server
          @server = nil
          @console_rd_pipe.close
          @console_wr_pipe.close
          @console_thread = nil
          
        rescue => e
          puts "Exception in server stop: #{e.to_s}, #{e.backtrace.join("\n")}"
        end
      end
      
      def self.server_log(message)
        Sigint_Trap.add_message(message) if defined?(Sigint_Trap)
        @console_wr_pipe.puts("#{message}<br>") if @console_connected
      end
    end
 
    Simple_server.server_start()
   
    def self.start_controlpanel()
      UI.start_timer(0.1, false) {
        link = "http://localhost:48484/controlpanel"
        system "start chrome --app=#{link}" if RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
        # system "open #{link}" if RbConfig::CONFIG['host_os'] =~ /darwin/
      }
    end
      
    def self.start_console()
      link = "http://localhost:48484/console.htm"
      system "start chrome --app=#{link}" if RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
      # system "open #{link}" if RbConfig::CONFIG['host_os'] =~ /darwin/
    end
    
    # start_console()
    
  end
end
nil

