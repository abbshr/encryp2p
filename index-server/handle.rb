require_relative "redis_storage"
require_relative "cert"
require "openssl"

module Handle

  # return with the signed-cert string
  def handle_registy data
    subject = "#{data[:ip]}-#{data[:port]}"
    pub_key = data[:pub_key]
    { :cert => Cert::issue(subject, pub_key) }
  end
  
  def handle_push data
    RedisStorage.new(data).get
  end

  def handle_list data
    RedisStorage::list
  end

  # return the CA pub_key & availiable src list
  def handle_pull data
    {
      :srcs => RedisStorage::find(data[:filename]),
      #RedisStorage::find_one data[:origin]
      :pub_key => Cert::pub_key
    }
  end
end