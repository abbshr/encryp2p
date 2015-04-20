require "socket"
require "openssl"
require_relative "d_handle"
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
        cert = handle_auth packet
        res = { :res => "auth", :cert => cert }
      when 'sync'
        key, iv, hash = handle_sync packet
        res = { :sync => TRUE, :res => "sync" }
      when 'fetch'
        encrypted = handle_fetch packet, key, iv, hash
        res = { :res => "fetch", :data => encrypted }
      else
        res = { :err => TRUE, :msg => "Invaild Command `#{packet[:cmd]}`" }
      end
      res = JSON.generate res
      puts res
      # response to node-client
      socket.write generate_packet res
    end
  }
end