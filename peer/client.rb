unless File.exist?("id.pem")
  puts "Warn: please generate a RSA private key before continue"
  raise "Can not find CA, please generate one before continue"
end

require "socket"
require "openssl"
require "base64"

require_relative "handle"
require_relative "../encp"

include Handle

begin
  index = TCPSocket.new "localhost", 2333
  connection = index.connect_address
rescue Exception => e
  puts "Index-Peer: Connection refused"
  Process.exit
end

encp = Encp.new

puts "[#{connection.ip_address}:#{connection.ip_port} - ] connection established"
print "command >"

Thread.new {
  loop do
    head, data, err = encp.parse(index)
    
    if err == :closed
      puts "lose connection, process exit"
      Process.exit
    end

    case head[:res]
    when "registy"
      # save the cert
      File.write "cert.cer", OpenSSL::X509::Certificate.new(head[:cert]).to_der
      puts "registy successfully, cert has been saved"
      print "command >"
    when "push"
      puts "your shared resource has been accepted by index peer"
      puts "meta Info:"
      puts "=========="
      puts "filename:\t#{head[:filename]}"
      puts "size:\t#{head[:size]} Bytes"
      puts "origin:\t#{head[:ip]}:#{head[:port]}"
      puts "=========="
      print "command >"
    when "pull"
      # get the CA public key
      ca_pub_key = OpenSSL::PKey::RSA.new head[:pub_key]
      # select a avaliable connection
      entry = head[:srcs].find do |entry|
        peer_ip = entry[:ip]
        peer_port = entry[:port].to_i
        filename = entry[:filename]

        begin
          # call the target peer
          peer = TCPSocket.new peer_ip, peer_port
          puts "connect to peer [#{peer_ip}:#{peer_port}]"
          sub_encp = Encp.new
        # state: 0
          # request to peer's cert
          peer.write encp.generate :cmd => 'auth'
          # waiting for response
          while recv = sub_encp.parse(peer)
            head, data, err = recv
            raise "Connection Reset by Peer" if err == :closed

            case head[:res]
            when "auth"
              cert = OpenSSL::X509::Certificate.new head[:cert]
              raise "Verify failed" unless cert.verify ca_pub_key
              # get the peer public key
              pub_key = cert.public_key
              File.write "pk", pub_key.export
            # state: 1
              # create & sync key, iv, hash
              decipher = OpenSSL::Cipher::AES256.new :CBC
              decipher.decrypt
              key = decipher.random_key
              File.binwrite "key-c", key
              key = pub_key.public_encrypt key
              req = { :cmd => 'sync_key' }
              peer.write sub_encp.generate req, key
            when "sync_key"
              # for SYNC KEY ACK packet
              raise "Unexpection error" unless head[:sync]
              iv = decipher.random_iv
              File.binwrite "iv-c", iv
              iv = pub_key.public_encrypt iv
              req = { :cmd => 'sync_iv' }
              peer.write sub_encp.generate req, iv
            when "sync_iv"
              # for SYNC IV ACK packet
              raise "Unexpection error" unless head[:sync]
              hash = pub_key.public_encrypt "SHA1"
              req = { :cmd => 'sync_hash' }
              peer.write sub_encp.generate req, hash
            when "sync_hash"
              # for SYNC HASH ACK packet
              raise "Unexpection error" unless head[:sync]
            # state: 2
              puts "fetching the resource..."
              req = { :cmd => "fetch", :filename => filename }
              peer.write sub_encp.generate req
            when "fetch"
              plain = decipher.update(data) + decipher.final
              # request for signature
              req = { :cmd => "fetch_sign" }
              peer.write sub_encp.generate req
            when "fetch_sign"
              signature = data
              digest = OpenSSL::Digest::SHA1.new
              raise "Invalid data" unless pub_key.verify digest, signature, plain
              # save the raw data
              File.binwrite "./receive/#{filename}", plain
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
      head[:list].each { |e| puts "#{e[:filename]}\t#{e[:size]}\t#{e[:ip]}" }
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
    index.write encp.generate :cmd => cmd, :pub_key => pub_key, :port => 6666
  when "push"
    print "filename >"
    filename = gets.chomp
    size = handle_push filename
    index.write encp.generate :size => size, :filename => filename, :cmd => cmd, :port => 6666
  when "pull"
    print "filename >"
    filename = gets.chomp
    index.write encp.generate :cmd => cmd, :filename => filename
  when "list"
    index.write encp.generate :cmd => cmd
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
