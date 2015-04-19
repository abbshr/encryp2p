require "socket"
require "openssl"
require_relative "handle"
require_relative "../util"

include Util

Socket.tcp_server_loop 666 do |socket, client_addrinfo|
  Thread.new {
    while (recv = parse_packet(socket))
      packet, err = recv
      packet.merge! :ip => client_addrinfo.ip_address, :port => client_addrinfo.ip_port    
      puts packet
      # fetch the command & handle it
      case packet[:cmd]
      when 'auth'
        res = handle_auth packet
      when 'sync'
        res = handle_sync packet
      when 'fetch'
        res = handle_fetch packet
      else
        res = { :err => TRUE, :msg => "Invaild Command `#{packet[:cmd]}`" }
      end
      res = JSON.generate res
      puts res
      # response to node-client
      socket.write generate_packet res
      socket.close
    end
  }
end