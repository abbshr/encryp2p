require "socket"
require "json"

Socket.tcp_server_loop 2333 do |socket|
  Thread.new {
    while data = socket.gets
      p data
      begin
        p JSON.parse data
      rescue Exception => e
        p e
      end
    end
  }
end