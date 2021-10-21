module SW
  module ProgressBarWebSocket
    module Simple_server
      @html_good = "HTTP/1.1 200\r\nContent-Type: text/html\r\n\r\n".freeze
      
      @html_not_found = "HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\nContent-Length:0\r\nConnection: close\r\n"
      
      @html_stopped = "HTTP/1.1 200\r\nContent-Type: text/html\r\n\r\nServer Shutting Down"
      
      @html_index = <<-EOF3
        <!DOCTYPE html>
        <html><body>
          Welcome to the SW Simple Server
        </body></html>        
      EOF3
      
      @html_console = "HTTP/1.1 200\r\nContent-Type: text/html\r\n\r\nConsole Server Started<script>function start_scroll_down(){scroll = setInterval(function(){ window.scrollBy(0, 1000); console.log('start');}, 1500);}start_scroll_down();</script> "

      @html_control_panel = <<-EOF2
        <!DOCTYPE html>
        <html><body>
        <form action="controlpanel_command.htm">
        <input type="submit" name="shut_down" value="Shut Down Server"><br><br>
        </body></html>
      EOF2


      def self.add_default_request_handlers()
        register_handler('/index.htm', method(:index_handler))
        register_handler('/favicon.ico', method(:favicon_handler))
        register_handler('/controlpanel.htm', method(:controlpanel_handler))
        register_handler('/controlpanel_command.htm', method(:controlpanel_command_handler))
        register_handler('/console.htm', method(:console_handler))
        register_handler('/SUCHAT/WSopen', method(:suchat_handler))
      end
      
      def self.index_handler(tcpsocket, request)
        response = ''
        response << @html_good
        response << @html_index
        tcpsocket.print response
        tcpsocket.close
      end
      
      def self.favicon_handler(tcpsocket, request)
        response = ''
        response << @html_not_found
        tcpsocket.print response
        tcpsocket.close
      end
      
      def self.controlpanel_handler(tcpsocket, request)
        response = ''
        response <<  @html_good
        response << @html_control_panel
        tcpsocket.print response
        tcpsocket.close
      end
      
      def self.controlpanel_command_handler(tcpsocket, request)
        proc = Proc.new {sleep(0.5); server_stop()}
        Sigint_Trap.add_message(proc)
        tcpsocket.print @html_stopped
        tcpsocket.close
      end
       
      def self.console_handler(tcpsocket, request)
        # TODO: There is a bit of a problem if we leave the console open
        # when we quite Sketchup. It seems either the Socket or the IO.pipe
        # is never closed and interferes with later instances of Sketchup. That's
        # my theory at least.
        
        # Close the previous concole
        @server_threads.delete( @console_thread) 
        @console_thread.exit() if @console_thread
        
        @console_thread = Thread.current
        @console_connected = true
        tcpsocket.print  "#{@html_console} #{Time.now.to_s}<br>Threads = #{@server_threads.size.to_s}<br>"
        loop do
          tcpsocket.print @console_rd_pipe.gets
        end
        rescue => e
          @console_connected = false
          # server_log("Console Crashed #{e.to_s}, #{e.backtrace.join("\n")}")
          tcpsocket.close
      end

    end
  end
end
nil

