require "redis-objects"
require "redis"
require "json"

class RedisStorage
  include Redis::Objects

  hash_key :entry

  def self::exist? origin
    true if redis.keys("redis_storage:#{origin}:*").count > 0
  end

  def prefix
    "redis_storage:"
  end

  def self::find_one origin
    return nil unless self::exist? origin
    entry = Redis::HashKey.new("redis_storage:#{origin}:entry").all
    JSON.parse(JSON.generate(entry), :symbolize_names => true)
  end

  def self::find filename
    redis.keys("redis_storage:*/#{filename}:entry").map do |e|
      JSON.parse(JSON.generate(Redis::HashKey.new(e).all), :symbolize_names => true)
    end
  end

  def self::list 
    redis.keys("redis_storage:*").map do |e|
      JSON.parse(JSON.generate(Redis::HashKey.new(e).all), :symbolize_names => true)
    end
  end

  def initialize data
    @origin = "#{data[:ip]}-#{data[:port]}/#{data[:filename]}"
    @entry = Redis::HashKey.new("#{prefix}#{@origin}:entry")
    @entry[:filename] = data[:filename]
    @entry[:size] = data[:size]
    @entry[:ip] = data[:ip]
    @entry[:port] = data[:port]
    @entry[:peer] = "#{data[:ip]}-#{data[:port]}"
  end

  def id
    @origin
  end

  def get
    JSON.parse JSON.generate(@entry.all), :symbolize_names => true
  end

  def set_origin origin
    @origin = origin
  end

  def set_entry entry
    @entry = entry
  end

end