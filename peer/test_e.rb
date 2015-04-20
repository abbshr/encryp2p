require "openssl"

data = "Very, very confidential data"

cipher = OpenSSL::Cipher::AES.new(128, :CBC)
cipher.encrypt
key = "qwerasdfzxcvqwer"
iv = "qwerasdfzxcvqwer"
cipher.key = key
cipher.iv = iv

encrypted = cipher.update(data) + cipher.final

decipher = OpenSSL::Cipher::AES.new(128, :CBC)
decipher.decrypt
decipher.key = key
decipher.iv = iv

plain = decipher.update(encrypted) + decipher.final

puts data, plain #=> true