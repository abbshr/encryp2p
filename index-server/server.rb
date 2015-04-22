unless File.exist?("CA.pem") || File.exist?("CA.cer")
  puts "Warn: use `ruby ca.rb to generate CA & priviate key`"
  raise "Can not find CA, please generate one before continue"
end

require "socket"
require "json"

require_relative "handle"
require_relative "../util"

include Util
include Handle

Socket.tcp_server_loop 2333 do |socket, client_addrinfo|
  # index server core logic
  Thread.new {
    while recv = parse_packet(socket)
      packet, err = recv
      Thread.exit if err == :closed
      packet.merge! :ip => client_addrinfo.ip_address
      puts packet
      # fetch the command & handle it
      res = case packet[:cmd]
      when 'registy'
        cert = handle_registy packet
        { :res => "registy", :cert => cert }
      when 'push'
        handle_push(packet).merge :res => "push"
      when 'pull'
        srcs, pub_key = handle_pull packet
        { :res => "pull", :srcs => srcs, :pub_key => pub_key }
      when 'list'
        list = handle_list packet
        { :res => "list", :list => list }
      else
        { :err => TRUE, :msg => "Invaild Command `#{packet[:cmd]}`" }
      end
      # response to node-client
      socket.write generate_packet res
    end
  }
end
