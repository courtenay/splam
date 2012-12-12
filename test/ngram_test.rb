require File.join(File.dirname(__FILE__), 'test_helper')
require "splam/ngram"
require "redis"
REDIS = Redis.new :db => "12"
class NgramTest < Test::Unit::TestCase

  def setup
    @corpus = Splam::Ngram.new

    # Will only try to stuff this into redis if it appears empty. Hacky, but works
    if REDIS.hlen("spam") < 50
      REDIS.expire "spam", 0
      REDIS.expire "ham", 0
    
      Dir.glob(File.join(File.dirname(__FILE__), "fixtures", "comment", "spam", "*.txt")).each do |f|
        spam = File.open(f).read
        @corpus.train spam, true
      end
      puts "loading ham"
      Dir.glob(File.join(File.dirname(__FILE__), "fixtures", "comment", "ham", "*.txt")).each do |f|
        ham = File.open(f).read
        @corpus.train ham, false
      end
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
