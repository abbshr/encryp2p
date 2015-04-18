require "socket"
require "json"

require_relative "../util"
include Util
while data = gets
  s = TCPSocket.new "localhost", 2333
  s.write generate_packet data
  p s.recv 1460
end
