require "socket"
require "openssl"

require_relativa "handle"
require_relative "../util"

include Util

index = TCPSocket.new "localhost", 2333
connection = index.connect_address

puts "[#{connection.ip_address}:#{connection.ip_port}] connection established"

Thread.new {
  while recv = parse_packet(index)
    packet, err = recv
    raise "lose connection, exit" if err == :closed
    case packet[:res]
    when "registy"
      # save the cert
      File.write "cert.cer", packet[:cert]
      puts "registy successfully, cert has been saved"
    when "push"
      puts "your shared resource has been accepted by index peer"
      puts "Info:"
      puts packet.delete("res").to_json
    when "pull"
      # get the CA public key
      ca_pub_key = OpenSSL::PKey::RSA.new packet[:pub_key]
      # select a avaliable connection
      entry = packet['srcs'].find do |entry|
        peer_ip = entry[:ip]
        peer_port = entry[:port]
        filename = entry[:filename]

        begin
          # call the target peer
          peer = TCPSocket.new peer_ip, peer_port
          puts "connect to peer [#{peer_ip}:#{{peer_port}}]"
          
        # state: 0
          # request to peer's cert
          peer.write generate_packet JSON.generate { :cmd => 'auth' }
          # waiting for response
          packet, err = parse_packet peer
          cert = OpenSSL::X509::Certificate.new packet[:cert]
          raise "Verify failed" unless cert.verify ca_pub_key
          # get the peer public key
          pub_key = cert.public_key
          
        # state: 1
          # create & sync key, iv, hash
          decipher = OpenSSL::Cipher::AES256.new :CBC
          decipher.decrypt
          key = decipher.random_key
          iv = decipher.random_iv
          hash = 'SHA1'
          req = { :cmd => 'sync', :key => key, :iv => iv, :hash => hash }
          peer.write generate_packet JSON.generate req
          # waiting for ACK packet
          packet, err = parse_packet peer
          raise "Unexpection error" unless packet[:sync]

        # state: 2
          puts "fetching the resource..."
          req = { :cmd => "fetch", :filename => filename }
          peer.write generate_packet JSON.generate req
          packet, err = parse_packet peer
          plain = decipher.update(packet[:data]) + decipher.final
          raw, signature = plain.split "\r\n"
          digest = OpenSSL::Digest::SHA1.new
          raise "Invalid data" unless pub_key.verify digest, signature, raw
          # save the raw data
          File.write "./share/#{filename}", raw
          puts "#{filename} from #{peer_ip}:#{peer_port} has been saved"

          # break the polling
          true
        rescue Exception => e
          puts "by some secret reason :)"
          puts "it seems that peer [#{peer_ip}:#{peer_port}] couldn't be accessd directly"
          puts "selecting next avaliable peer..."
          next
        end
      end
      # all connections failed
      puts "no avaliable peer to fetch the resource" unless entry
    when "list"
    end
  end
}

# block the main thread
print "commands:>_"
cmd = gets.chomp
# public commands list
case cmd
# self registy, get a cert from index server
when "registy"
  pub_key = handle_registy
  req = { :cmd => cmd, :pub_key => pub_key }
when "push"
  filename = gets.chomp
  req = handle_push filename
  req.merge :cmd => cmd
when "pull"
  filename = gets.chomp
  req = handle_pull filename
  req.merge :cmd => cmd
when "list"
  req = { :cmd => cmd }
else
  req = { :cmd => "private" }
end

index.write generate_packet JSON.generate req
