require "socket"
require "openssl"
require_relative "handle"

Socket.tcp_server_loop 666 do |socket, client_addrinfo|
  Thread.new {
    # parse the packet
    packet = JSON.parse socket.recv 1460, :symbolize_names => true
    packet.merge! :ip => client_addrinfo.ip_address, :port => client_addrinfo.ip_port
    p packet
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
    p res
    res = JSON.generate res
    # response to node-client
    socket.write res
    socket.close
  }
end