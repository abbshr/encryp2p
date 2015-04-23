unless File.exist?("CA.pem") || File.exist?("CA.cer")
  puts "Warn: use `ruby ca.rb to generate CA & priviate key`"
  raise "Can not find CA, please generate one before continue"
end

require "socket"
require "json"

require_relative "handle"
require_relative "../encp"

include Handle

Socket.tcp_server_loop 2333 do |socket, client_addrinfo|
  # index server core logic
  Thread.new {
    encp = Encp.new

    while recv = encp.parse(socket)
      head, data, err = recv
      Thread.exit if err == :closed
      head.merge! :ip => client_addrinfo.ip_address
      # fetch the command & handle it
      res = case head[:cmd]
      when 'registy'
        cert = handle_registy head
        { :res => "registy", :cert => cert }
      when 'push'
        handle_push(head).merge :res => "push"
      when 'pull'
        srcs, pub_key = handle_pull head
        { :res => "pull", :srcs => srcs, :pub_key => pub_key }
      when 'list'
        list = handle_list head
        { :res => "list", :list => list }
      else
        { :err => TRUE, :msg => "Invaild Command `#{head[:cmd]}`" }
      end
      # response to node-client
      socket.write encp.generate res
    end
  }
end
