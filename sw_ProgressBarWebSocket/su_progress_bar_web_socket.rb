require 'json'

#Warning!!!
# these examples are way out of date

#############################################
#
# Initializer:
#   new() -> progressbar
#   new() { |progressbar| block } -> result of block
#
# If a code block is given the progressbar will be shown, the code block will be
# executed, and the progressbar will then be hidden. The progressbar instance
# will be passed to the code block as an arguement. With no associated block the
# progressbar instance will be returned to the caller. The caller will then be
# responsible for showing and hiding the progressbar.
#
# block example:
# module SW::ProgressBarWebSocketExample
#   def self.run_demo1()
#     begin
#       model = Sketchup.active_model.start_operation('Progress Bar Example', true)
#       SW::ProgressBarWebSocket::ProgressBar.new {|pbar|
#         100.times {|i|
#           # modify the sketchup model here
#           sleep(0.01)
#           # update the progressbar
#           if pbar.update?
#             pbar.label= "Remaining: #{100 - i}"
#             pbar.set_value(i)
#             pbar.refresh
#           end
#         }
#       }
#       Sketchup.active_model.commit_operation
#     rescue => exception
#       Sketchup.active_model.abort_operation
#       raise exception
#     end
#   end
#   run_demo1()
# end
#
# no block example:
# module SW::ProgressBarWebSocketExample
#   def self.run_demo2()
#     begin
#       model = Sketchup.active_model.start_operation('Progress Bar Example', true)
#       pbar = SW::ProgressBarWebSocket::ProgressBar.new
#       pbar.show
#       100.times {|i|
#         # modify the sketchup model
#         sleep(0.01)
#         # update the progressbar
#         if pbar.update?
#           pbar.label= "Remaining: #{100 - i}"
#           pbar.set_value(i)
#           pbar.refresh
#         end
#       }
#       Sketchup.active_model.commit_operation
#     rescue => exception
#       Sketchup.active_model.abort_operation
#       raise exception
#     ensure pbar.hide
#     end
#   end
#   run_demo2()
# end
# 

module SW
  module ProgressBarWebSocket
    # Exception class for Progress bar user code errors
    class ProgressBarError < RuntimeError; end

    # Exception class for Progress bar user code errors
    class ProgressBarAbort < RuntimeError; end

    class ProgressBar
      @@html_good = "HTTP/1.1 200\r\nContent-Type: text/html\r\n\r\n".freeze

      def initialize(dialog_path, &block)
        @dialog_path = dialog_path
        if block
          begin
            show()
            block.call(self)
          ensure
            hide()
          end
        end
      end # initialize
   
      # Show the progress bar
      def show()
        activate()
      end

      def hide()
        deactivate()
      end
         
      def activate
        @activated = true
        @update_interval = 0.1
        register_with_server_and_show()
        start_update_thread()
      end

      # Stop the updater thread
      # Signal the dialog to close
      # End the tcpsocket connection
      def deactivate()
        @activated = false
        stop_update_thread()
        @server.web_socket_close()
      end
      
      # Send status to the progressbar
      # @param status [Hash]
      def refresh(status)
        params = status.to_json
        @server.web_socket_write(params)
        response = @server.web_socket_read()
        raise ProgressBarAbort, "User Cancel Clicked" if response == "UserCancelClicked"
        raise ProgressBarAbort, "User Close Dialog" if response && response.match('^SUCHAT_Close')
        response  
      end
        
      # The update? method returns true approximately every @update_interval.
      # To regulate the frequency of refreshes the user code should query
      # the update? flag and refresh when the returned value is true.
      def update?
        temp = @update_flag
        @update_flag = false
        temp
      end
     
      def register_with_server_and_show()
        @server = Simple_server.get_server()
        @server.web_socket_new()
        @server.register_handler('/SUPBWS/progressbar.htm', method(:progressbar_handler))
        link = "http://localhost:48484/SUPBWS/progressbar.htm"
        system_call("chrome --app=#{link}") if RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
        #system "start chrome --app=#{link}" if RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
        system "open #{link}" if RbConfig::CONFIG['host_os'] =~ /darwin/
      end
      
      # Eneroth's system_call()
      # Run system call without flashing command line window on Windows.
      # Runs asynchronously.
      # Windows only hack.
      #
      # @param cmd String.
      #
      # @return [Void].
      def system_call(cmd)
        # HACK: Run the command through a VBS script to avoid flashing command line
        # window.
        file = Tempfile.new(["cmd", ".vbs"])
        file.write("Set WshShell = CreateObject(\"WScript.Shell\")\n")
        file.write("WshShell.Run \"#{cmd.gsub('"', '""')}\", 0\n")
        file.close
        UI.openURL("file://#{file.path}")
        nil
      end
      
      # Serve the user defined progressbar dialog to the browser
      # Insert a unique instance identifier into the javascript
      # before sending the page to the browser.
      #
      def progressbar_handler(tcpsocket, params_hash)
        uniqueID = @server.web_socket_get_uniqueID()      
        dialog_path = @dialog_path.force_encoding("UTF-8") if @dialog_path.respond_to?(:force_encoding)
        File.open(dialog_path, 'r') { |f|
          response = ''
          response <<  @@html_good
          data = f.read
          response << data.sub("Connection_ID", "Connection_ID #{uniqueID}")
          tcpsocket.print response
        }
        tcpsocket.close
      end
           
 
      ###################################
      # Timed update? routines 
      ###################################
      
      def start_update_thread()
        @update_thread = Thread.new() {update_loop()}
        @update_thread.priority = 1
      end
      private :start_update_thread
      
      def stop_update_thread()
        @update_thread.exit if @update_thread.respond_to?(:exit)
        @update_thread = nil
      end
      private :stop_update_thread
      
      # A simple thread which will set the @update_flag approximately 
      # every @update_interval + @redraw_delay. 
      def update_loop()
        while @activated
          sleep(@update_interval)
          @update_flag = true
        end 
      end
      private :update_loop
      
    end # progressbar
  end
end
nil

