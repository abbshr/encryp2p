require_relative "redis_storage"
require_relative "cert"
require "openssl"

module Handle

  # return with the signed-cert string
  def handle_registy data
    Cert::issue "#{data[:ip]}-#{data[:port]}", data[:pub_key]
  end
  
  def handle_push data
    RedisStorage.new(data).get
  end

  def handle_list data
    RedisStorage::list
  end

  # return the CA pub_key & availiable src list
  def handle_pull data
    [RedisStorage::find(data[:filename]) , Cert::pub_key]
  end
end