require File.expand_path('test_helper', File.dirname(__FILE__))
require "splam/ngram"
# needs a Redis on localhost (db 12); omitted without one
begin
  require "redis"
  REDIS = Redis.new :db => "12" unless defined?(REDIS)
  REDIS.ping
  NGRAM_REDIS = true
rescue StandardError, LoadError
  NGRAM_REDIS = false
end

class NgramTest < Test::Unit::TestCase

  def setup
    omit("needs Redis on localhost:6379") unless NGRAM_REDIS
    @corpus = Splam::Ngram.new

    REDIS.del "ham"
    REDIS.del "spam"
    
    Dir.glob(File.join(File.dirname(__FILE__), "fixtures", "comment", "spam", "*.txt")).each do |f|
      spam = File.open(f).read
      @corpus.train spam, true
    end
    Dir.glob(File.join(File.dirname(__FILE__), "fixtures", "comment", "ham", "*.txt")).each do |f|
      ham = File.open(f).read
      @corpus.train ham, false
    end
  end
  
  def test_learns_spam
    score = @corpus.compare("Bienvenido a nuestro nuevo portal porno")
    assert score[1] > score[0] * 2
  end
  
  def test_learns_ham
    score = @corpus.compare("Is this a known issue?")
    assert score[0] > score[1] * 2
  end
end
