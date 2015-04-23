require "openssl"
require "base64"

module Handle

  PRIVATE_KEY = OpenSSL::PKey::RSA.new File.read "./id.pem"
  CERTIFICATE = OpenSSL::X509::Certificate.new File.read "./cert.cer"

  # return the cert issued from CA index-server
  def handle_auth data
    CERTIFICATE.to_pem
  end

  # return the random key for AES and hash algorithm
  # decrypt the data using the private key

  def handle_sync_key enc_key
    PRIVATE_KEY.private_decrypt enc_key
  end

  def handle_sync_iv enc_iv
    PRIVATE_KEY.private_decrypt enc_iv
  end

  def handle_sync_hash enc_hash
    PRIVATE_KEY.private_decrypt enc_hash
  end

  def handle_fetch head, key, iv, hash
    raw = File.binread "./share/#{head[:filename]}"
    digest = OpenSSL::Digest.new hash
    signature = PRIVATE_KEY.sign digest, raw
    File.binwrite "sign", signature
    # encrypt the signature and rawdata using AES
    cipher = OpenSSL::Cipher.new "AES-256-CBC"
    # encrypt mode
    cipher.encrypt
    cipher.key = key
    cipher.iv = iv
    [signature, cipher.update(raw) + cipher.final]
  end

  def handle_fetch_sign signature, key, iv
    signature
  end

end
