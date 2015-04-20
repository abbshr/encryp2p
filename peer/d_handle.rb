require "openssl"

module Handle

  PRIVATE_KEY = OpenSSL::PKey::RSA.new File.read "./id.key"
  CERTIFICATE = OpenSSL::X509::Certificate.new File.read "./cert.cer"

  # return the cert issued from CA index-server
  def handle_auth data
    CERTIFICATE.to_pem
  end

  # return the random key for AES and hash algorithm
  def handle_sync data
    enc_key = data[:key]
    enc_iv = data[:iv]
    hash = data[:hash]
    # decrypt the data using the private key
    [
      PRIVATE_KEY.private_decrypt enc_key, 
      PRIVATE_KEY.private_decrypt enc_iv, 
      PRIVATE_KEY.private_decrypt hash
    ]
  end

  def handle_fetch data, key, iv, hash
    target = data[:filename]
    raw = File.read "./share/#{target}"
    digest = OpenSSL::Digest.new hash
    signature = PRIVATE_KEY.sign digest, raw
    # encrypt the signature and rawdata using AES
    cipher = OpenSSL::Cipher.new "AES-256-CBC"
    # encrypt mode
    cipher.encrypt
    cipher.key = key
    cipher.iv = iv
    cipher.update("#{raw}\r\n#{signature}") + cipher.final
  end
end
