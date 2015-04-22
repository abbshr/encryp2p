require "socket"
require "openssl"
require_relative "d_handle"
require_relative "../util"

include Util
include Handle

Socket.tcp_server_loop 6666 do |socket, client_addrinfo|
  Thread.new {
    while (recv = parse_packet(socket))
      packet, err = recv
      Thread.exit if err == :closed
      packet.merge! :ip => client_addrinfo.ip_address, :port => client_addrinfo.ip_port    
      # fetch the command & handle it
      res = case packet[:cmd]
      when 'auth'
        { :res => "auth", :cert => handle_auth(packet) }
      when 'sync'
        key, iv, hash = handle_sync packet
        { :sync => TRUE, :res => "sync" }
      when 'fetch'
        encrypted = handle_fetch packet, key, iv, hash
        { :res => "fetch", :data => encrypted }
      else
        { :err => TRUE, :msg => "Invaild Command `#{packet[:cmd]}`" }
      end
      # response to node-client
      puts res
      socket.write generate_packet res
    end
  }
end