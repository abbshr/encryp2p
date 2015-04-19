require "json"

module Util

  ENDCODE = "END\r\n"

  def generate_packet json_data
    "#{json_data}\n#{ENDCODE}"
  end

  def parse_packet socket
    packet = []
    err = :none
    
    # parse the packet
    until ENDCODE == (chunk = socket.gets)
      puts chunk
      if chunk.nil?
        err = :closed
        packet = ["{}"] if packet.size == 0
        break
      end
      packet << chunk
    end
    
    begin
      packet = JSON.parse packet.join, :symbolize_names => true
    rescue Exception => e
      packet = {}
      err = :parse_error
    end

    [packet, err]
  end
end