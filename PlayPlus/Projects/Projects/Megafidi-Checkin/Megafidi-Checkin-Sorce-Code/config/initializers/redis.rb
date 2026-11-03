# config/initializers/redis.rb

$redis = Redis::Namespace.new(ENV['redis_name'], :redis => Redis.new)