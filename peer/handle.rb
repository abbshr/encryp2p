require "openssl"

module Handle

  PRIVATE_KEY = OpenSSL::PKey::RSA.new File.read "./id.pem"

  def handle_registy
    PRIVATE_KEY.public_key.export
  end
  
  def handle_push filename
    File.size "share/#{filename}"
  end
end