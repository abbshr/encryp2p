require "socket"
require "json"

require_relative "../util"
include Util

s = TCPSocket.new "localhost", 2333

Thread.new {
  loop { 
    packet, err = parse_packet(s)
    puts packet
    s = TCPSocket.new "localhost", 2333 if err == :closed
  }
}

loop { s.write generate_packet gets.chomp }
