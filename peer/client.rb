unless File.exist?("id.pem")
  puts "Warn: please generate a RSA private key before continue"
  raise "Can not find CA, please generate one before continue"
end

require "socket"
require "openssl"
require "base64"

require_relative "handle"
require_relative "../util"

include Util
include Handle

begin
  index = TCPSocket.new "localhost", 2333
  connection = index.connect_address
rescue Exception => e
  puts "Index-Peer: Connection refused"
  Process.exit
end

puts "[#{connection.ip_address}:#{connection.ip_port} - ] connection established"
print "command >"

Thread.new {
  loop do
    packet, err = parse_packet(index)
    
    if err == :closed
      puts "lose connection, process exit"
      Process.exit
    end
    case packet[:res]
    when "registy"
      # save the cert
      File.write "cert.cer", OpenSSL::X509::Certificate.new(packet[:cert]).to_der
      puts "registy successfully, cert has been saved"
      print "command >"
    when "push"
      puts "your shared resource has been accepted by index peer"
      puts "meta Info:"
      puts "=========="
      puts "filename:\t#{packet[:filename]}"
      puts "size:\t#{packet[:size]} Bytes"
      puts "origin:\t#{packet[:ip]}:#{packet[:port]}"
      puts "=========="
      print "command >"
    when "pull"
      # get the CA public key
      ca_pub_key = OpenSSL::PKey::RSA.new packet[:pub_key]
      # select a avaliable connection
      entry = packet[:srcs].find do |entry|
        peer_ip = entry[:ip]
        peer_port = entry[:port].to_i
        filename = entry[:filename]

        begin
          # call the target peer
          peer = TCPSocket.new peer_ip, peer_port
          puts "connect to peer [#{peer_ip}:#{peer_port}]"
        # state: 0
          # request to peer's cert
          peer.write generate_packet :cmd => 'auth'
          # waiting for response
          while recv = parse_packet(peer)
            packet, err = recv
            raise "Connection Reset by Peer" if err == :closed

            case packet[:res]
            when "auth"
              cert = OpenSSL::X509::Certificate.new packet[:cert]
              raise "Verify failed" unless cert.verify ca_pub_key
              # get the peer public key
              pub_key = cert.public_key
            # state: 1
              # create & sync key, iv, hash
              decipher = OpenSSL::Cipher::AES256.new :CBC
              decipher.decrypt
              hash = pub_key.public_encrypt("SHA1").unpack "H*"
              key = decipher.random_key.unpack("H*")[0]
              iv = decipher.random_iv.unpack("H*")[0]
              decipher.key = key
              decipher.iv = iv
              key = pub_key.public_encrypt(key).unpack "H*"
              iv = pub_key.public_encrypt(iv).unpack "H*"
              req = { :cmd => 'sync', :key => key, :iv => iv, :hash => hash }
              peer.write generate_packet req
            when "sync"
              # for SYNC ACK packet
              raise "Unexpection error" unless packet[:sync]
            # state: 2
              puts "fetching the resource..."
              req = { :cmd => "fetch", :filename => filename }
              peer.write generate_packet req
            when "fetch"
              plain = decipher.update(Base64.decode64(packet[:data])) + decipher.final
              raw, signature = plain.split "\r\n"
              digest = OpenSSL::Digest::SHA1.new
              raw = Base64.decode64 raw
              signature = Base64.decode64 signature
              #raise "Invalid data" unless pub_key.verify digest, signature, raw
              # save the raw data
              File.write "./receive/#{filename}", raw
              puts "#{filename} from #{peer_ip}:#{peer_port} has been saved"
              # break the polling
              break
            end
          end
          true
        rescue Exception => e
          puts "It seems that peer [#{peer_ip}:#{peer_port}] couldn't be accessd directly"
          puts "Reason: #{e}"
          puts "selecting next avaliable peer..."
          next
        end
      end
      # all connections failed
      puts "no avaliable peer to fetch the resource" unless entry
      print "command >"
    when "list"
      puts "FileName\t\tSize(B)\t\tSource"
      packet[:list].each { |e| puts "#{e[:filename]}\t#{e[:size]}\t#{e[:ip]}" }
      print "command >"
    end
  end
}

# block the main thread
loop do
  cmd = gets.chomp
  # public commands list
  case cmd
  # self registy, get a cert from index server
  when "registy"
    pub_key = handle_registy
    index.write generate_packet :cmd => cmd, :pub_key => pub_key, :port => 6666
  when "push"
    print "filename >"
    filename = gets.chomp
    size = handle_push filename
    index.write generate_packet :size => size, :filename => filename, :cmd => cmd, :port => 6666
  when "pull"
    print "filename >"
    filename = gets.chomp
    index.write generate_packet :cmd => cmd, :filename => filename
  when "list"
    index.write generate_packet :cmd => cmd
  when "exit"
    index.close
    Process.exit
  else
    puts <<EOF
    INDEX-PEER PUBLIC COMMANDS HELP
    ===============
    registy - apply a cert from index
    push    - publish a shared file meta info to index
    pull    - download a shared file from peer
    list    - list all shared files
EOF
  print "command >"
  end
end
