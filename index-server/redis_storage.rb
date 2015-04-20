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
    Redis::HashKey.new("redis_storage:#{origin}:entry").all
  end

  def self::find filename
    return nil unless self::exist? "*/#{filename}"
    redis.keys("redis_storage:*/#{filename}:entry").map do |e|
      entry = Redis::HashKey.new e
    end
  end

  def self::list 
    redis.keys("redis_storage:*").map do |e|
      enrty = Redis::HashKey.new e
    end
  end

  def initialize data
    @origin = "#{data[:ip]}-#{data[:port]}/#{data[:filename]}"
    @entry = Redis::HashKey.new("#{prefix}#{origin}:entry")
    @entry[:filename] = data[:filename]
    @entry[:size] = data[:size]
    @entry[:type] = data[:type]
    @entry[:ip] = data[:ip]
    @entry[:port] = data[:port]
    @entry[:peer] = "#{data[:ip]}-#{data[:port]}"
  end

  def id
    @origin
  end

  def get
    @entry.all
  end

  def set_origin origin
    @origin = origin
  end

  def set_entry entry
    @entry = entry
  end

end