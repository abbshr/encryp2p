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
    while (recv = parse_packet(socket))
      packet, err = recv
      packet.merge! :ip => client_addrinfo.ip_address, :port => client_addrinfo.ip_port
      puts packet
      # fetch the command & handle it
      case packet[:cmd]
      when 'registy'
        res = handle_registy packet
      when 'push'
        res = handle_push packet
      when 'pull'
        res = handle_pull packet
      when 'list'
        res = handle_list packet
      else
        res = { :err => TRUE, :msg => "Invaild Command `#{packet[:cmd]}`" }
      end
      res = JSON.generate res
      puts res
      # response to node-client
      socket.write generate_packet res
      #socket.close
    end
  }
end
