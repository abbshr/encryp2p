require "openssl"

module Cert

  ROOT_CA = OpenSSL::X509::Certificate.new File.read "CA.cer"
  ROOT_KEY = OpenSSL::PKey::RSA.new File.read "CA.pem"

  def self::pub_key
    ROOT_KEY.public_key.export
  end

  def self::read path
    #@cached || @cached = @cert.readlines
    raw = File.read "./CA/#{path}.cer" # DER- or PEM-encoded
    certificate = OpenSSL::X509::Certificate.new raw
  end

  def self::issue subject, public_key
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 2
    cert.subject = OpenSSL::X509::Name.parse "/DC=root/CN=#{subject} CA"
    cert.issuer = ROOT_CA.subject # root CA is the issuer
    cert.public_key = OpenSSL::PKey::RSA.new public_key
    cert.not_before = Time.now
    cert.not_after = cert.not_before + 1 * 365 * 24 * 60 * 60 # 1 years validity
    ef = OpenSSL::X509::ExtensionFactory.new
    ef.subject_certificate = cert
    ef.issuer_certificate = ROOT_CA
    cert.add_extension(ef.create_extension("keyUsage","digitalSignature", true))
    cert.add_extension(ef.create_extension("subjectKeyIdentifier","hash",false))
    cert.sign(ROOT_KEY, OpenSSL::Digest::SHA256.new)
    cert.to_pem
  end
end