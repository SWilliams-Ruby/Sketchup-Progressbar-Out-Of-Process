require 'thread'
require 'digest/sha1'

# WebSocket Protocol Specs 
# https://tools.ietf.org/id/draft-ietf-hybi-thewebsocketprotocol-09.html#rfc.section.4.1
# low byte first - nework order
#  0               1               2               3
#  7 6 5 4 3 2 1 0 7 6 5 4 3 2 1 0 7 6 5 4 3 2 1 0 7 6 5 4 3 2 1 0 
# +-+-+-+-+-------+-+-------------+-------------------------------+
# |F|R|R|R| opcode|M| Payload len |    Extended payload length    |
# |I|S|S|S|  (4)  |A|     (7)     |             (16/63)           |
# |N|V|V|V|       |S|             |   (if payload len==126/127)   |
# | |1|2|3|       |K|             |                               |
# +-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
# |     Extended payload length continued, if payload len == 127  |
# + - - - - - - - - - - - - - - - +-------------------------------+
# |                               |Masking-key, if MASK set to 1  |
# +-------------------------------+-------------------------------+
# | Masking-key (continued)       |          Payload Data         |
# +-------------------------------- - - - - - - - - - - - - - - - +
# :                     Payload Data continued ...                :
# + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
# |                     Payload Data continued ...                |
# +---------------------------------------------------------------+
#
# Opcode: 4 bits
# Defines the interpretation of the payload data. If an unknown
# opcode is received, the receiving endpoint MUST ignore that frame.
# The following values are defined.
# %x0 denotes a continuation frame
# %x1 denotes a text frame
# %x2 denotes a binary frame
# %x3-7 are reserved for further non-control frames
# %x8 denotes a connection close
# %x9 denotes a ping
# %xA denotes a pong
# %xB-F are reserved for further control frames
#

# What follows is a very short and incomplete WebSocket implementation
#
module SW
  module ProgressBarWebSocket
    module Simple_server
      def self.websocket_handler(tcpsocket, request, websocket_key)
        complete_handshake(tcpsocket, websocket_key)
        transfer_full_duplex(tcpsocket)
        server_log("Closing tcpsocket")
        tcpsocket.close
      end
      
      def self.complete_handshake(tcpsocket, websocket_key)
        response_key = Digest::SHA1.base64digest([websocket_key, "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"].join)
        tt = "HTTP/1.1 101 Switching Protocols\nUpgrade:websocket\nConnection: Upgrade\nSec-WebSocket-Accept: #{ response_key }\n\n"
        tcpsocket.write tt
      end
      
      # Transfer inbound messages from the tcpsocket to 
      # the inbound_queue,  Transfer outbound messages
      # from the outbound_pipe to the tcpsocket.
      #
      def self.transfer_full_duplex(tcpsocket)
        @running = true
        while @running
          readable = IO.select([@outbound_pipe_rd, tcpsocket])[0]
          readable.each { |io|
            outbound_transfer(tcpsocket) if (io == @outbound_pipe_rd)
            inbound_transfer(tcpsocket) if (io == tcpsocket) && @running
          }
        end
      end # handle_websocket

      
      def self.outbound_transfer(tcpsocket)
        outbound_message = @outbound_pipe_rd.gets()
        if outbound_message.match('^SUCHAT_CloseSocket')
          @running = false
          # server_log('websocket stopped via SUCHAT_CloseSocket')
        else
          if outbound_message.size < 126
            output = [0b10000001, outbound_message.size, outbound_message]
            tcpsocket.write output.pack("CCA#{ outbound_message.size }")
          elsif outbound_message.size < 65536
            output = [0b10000001, 126, outbound_message.size, outbound_message]
            tcpsocket.write output.pack("CCnA#{ outbound_message.size }")
          else
            output = [0b10000001, 127, outbound_message.size, outbound_message]
            tcpsocket.write output.pack("CCQ>A#{ outbound_message.size }")
          end
        end
      end

      # Inbound transfer
      def self.inbound_transfer(tcpsocket)
        inbound_message = read_frame(tcpsocket)
        accept_connection(tcpsocket, inbound_message)
        @inbound_queue << inbound_message if inbound_message
      end
      
      # An incoming connection 'must' have the correct connectionID
      # and sushcat must be in the :waiting state
      #
      def self.accept_connection(tcpsocket, inbound_message)
        if /SUCHAT_Connect/ =~ inbound_message
          uniqueID = inbound_message.split(":")[1].split(" ")[1]
          if (uniqueID.to_i == @suchat_uniqueID) and  (@suchat_status == :waiting)
            @suchat_status = :connected
          else
            # setting run to false will close the tcpsocket and the browser
            @running = false
          end
        end
      end

      def self.read_frame(tcpsocket)
        begin
          # server_log('in read_frame')
          first_byte = tcpsocket.getbyte
          fin = first_byte & 0b10000000
          opcode = first_byte & 0b00001111
          second_byte = tcpsocket.getbyte
          is_masked = second_byte & 0b10000000
          payload_size = second_byte & 0b01111111
           
          if payload_size == 126 
            payload_size = tcpsocket.read(2).unpack('n')[0]
          elsif payload_size == 127 
            payload_size = tcpsocket.read(8).unpack('Q>')[0] 
          end

          raise "We don't support continuations" unless fin
          raise "We only support opcode 1 & 8" unless (opcode == 1 or opcode == 8)
          raise "All incoming frames should be masked according to the websocket spec" unless is_masked

          # unmask the data
          mask = 4.times.map { tcpsocket.getbyte }
          data = payload_size.times.map { tcpsocket.getbyte }
          message = data.each_with_index.map { |byte, i| (byte ^ mask[i % 4]).chr }.join
          
          if opcode == 8
            @running = false 
            message = "SUCHAT_Close:WebSocket Client Disconnected with Code: #{message.unpack('n')}"
            server_log(message)
          end
          
          return message 
          
        # If the TCP connection closes before we have received the WebSocket close
        # command, we may receive ECONNABORTED when we try to read the TCP Socket
        rescue Errno::ECONNABORTED
          @running = false
          message = "SUCHAT_Close:WebSocket Client Disconnected with Errno::ECONNABORTED"
          server_log(message)
          return message
        #rescue => e
          # @running = false
          # server_log("#{e.to_s}, #{e.backtrace.join("\n")}")
          # message = nil
          # raise e
        end
      end
          
      ################################
      # Public Methods
      ################################
      
      # three states
      # :waiting
      # :connected
      # :closed
      
      # special messages
      # 'SUCHAT_CloseBrowser'
      # 'SUCHAT_CloseSocket'

      def self.web_socket_new()
        @suchat_status = :waiting
        @inbound_queue = Queue.new
        @outbound_pipe_rd, @outbound_pipe_wr = IO.pipe
        @suchat_uniqueID = ((Time.now - @server_start_time) * 1000000).to_i
        true
      end

      # Disable new inbound connection
      # Send Browser Close Message
      # Send the tcpsocket close message
      def self.web_socket_close()
        web_socket_write('SUCHAT_CloseBrowser')
        web_socket_write('SUCHAT_CloseSocket')
        @suchat_status = :closed
        true
      end

      def self.web_socket_get_uniqueID()   
        @suchat_uniqueID
      end
      
      # Write to the outbound stream if the a browser is connected
      #
      # @return  @suchat_status
      #
      def self.web_socket_write(outbound_message)
           @outbound_pipe_wr.puts(outbound_message) if @suchat_status == :connected
           @suchat_status 
      end

      # Read  inbound stream
      # return String or nil
      def self.web_socket_read()      
        inbound_message = @inbound_queue.pop(true) rescue inbound_message = nil
      end
      
      def self.suchat_handler(tcpsocket, request)
        # server_log(request)
        if matches = request.match(/^Sec-WebSocket-Key: (\S+)/)
           websocket_handler(tcpsocket, request, matches[1])
        else
          response = "HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\nContent-Length:0\r\nConnection: close\r\n"
          tcpsocket.print response
          tcpsocket.close
        end
      end
     
    end 
  end
end
nil

