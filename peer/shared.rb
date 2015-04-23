require "socket"
require "openssl"
require_relative "d_handle"
require_relative "../encp"

include Handle

Socket.tcp_server_loop 6666 do |socket, client_addrinfo|
  Thread.new {
    encp = Encp.new
    while recv = encp.parse(socket)
      head, data, err = recv
      Thread.exit if err == :closed
      head.merge! :ip => client_addrinfo.ip_address, :port => client_addrinfo.ip_port    
      # fetch the command & handle it
      res = case head[:cmd]
      when 'auth'
        { :res => "auth", :cert => handle_auth(head) }
      when 'sync_key'
        key = handle_sync_key data
        { :sync => TRUE, :res => "sync_key" }
      when 'sync_iv'
        iv = handle_sync_iv data
        { :sync => TRUE, :res => "sync_iv" }
      when 'sync_hash'
        hash = handle_sync_hash data
        { :sync => TRUE, :res => "sync_hash" }
      when 'fetch'
        signature, data = handle_fetch head, key, iv, hash
        { :res => "fetch" }
      when 'fetch_sign'
        data = handle_fetch_sign signature, key, iv
        { :res => "fetch_sign" }
      else
        { :err => TRUE, :msg => "Invaild Command `#{head[:cmd]}`" }
      end
      # response to node-client
      socket.write encp.generate res, data
    end
  }
end