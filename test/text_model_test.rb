# encoding: UTF-8
require File.expand_path('test_helper', File.dirname(__FILE__))

module TextModelTests
  def train_a_little(m)
    m.train(1, "buy cheap viagra pills now", :spam)
    m.train(2, "cheap viagra online pharmacy", :spam)
    m.train(3, "I cannot log in to my account", :ham)
    m.train(4, "the login page shows an error", :ham)
  end

  def test_scores_by_what_it_learned
    m = model
    train_a_little(m)
    assert_operator m.score("cheap viagra here")[:probability], :>, 0.9
    assert_operator m.score("my login shows an error")[:probability], :<, 0.1
    assert_equal "w:cheap", m.score("cheap viagra here")[:spam_features].first.first
  end

  def test_training_is_keyed_by_document
    m = model
    train_a_little(m)
    before = m.stats
    assert_equal false, m.train(1, "buy cheap viagra pills now", :spam) # same label: nothing
    assert_equal before, m.stats
    assert_equal true, m.train(1, "buy cheap viagra pills now", :ham)   # relabelled: counts move once
    assert_equal before[:spam_docs] - 1, m.stats[:spam_docs]
    assert_equal before[:ham_docs] + 1, m.stats[:ham_docs]
    assert_equal before[:spam_tokens] + before[:ham_tokens], m.stats[:spam_tokens] + m.stats[:ham_tokens]
    m.train(1, "anything", nil) # forgotten
    assert_equal before[:ham_docs], m.stats[:ham_docs]
  end

  def test_counts_never_go_below_zero
    m = model
    m.train(1, "short text", :spam)
    m.train(2, "other", :ham)
    m.train(1, "a much longer text than the one trained", nil) # untrained with different text
    assert_operator m.stats[:spam_tokens], :>=, 0
    assert_operator m.stats[:spam_vocab], :>=, 0
  end

  def test_neutral_without_both_labels
    m = model
    m.train(1, "only spam so far", :spam)
    assert_equal 0.5, m.score("only spam")[:probability]
  end
end

class TextModelTest < Test::Unit::TestCase
  include TextModelTests

  def model
    Splam::TextModel.new(Splam::TextModel::MemoryStore.new)
  end

  def test_features
    f = model.features("Buy cheap Viagra! 我无法登录, it's fine")
    assert_equal 1, f["w:viagra"]
    assert_equal 1, f["w:it's"]
    assert_equal 1, f["c:登录"]                     # Chinese: character pairs
    assert_equal 1, f["t:buy cheap viagra"]
    assert !f.key?("w:我无法登录")
  end

  def test_considers_the_first_max_chars
    m = Splam::TextModel.new(Splam::TextModel::MemoryStore.new, :max_chars => 10)
    assert !m.features("0123456789 viagra").key?("w:viagra")
  end

  def test_prune_drops_rare_features_and_keeps_totals_right
    m = model
    train_a_little(m)
    m.train(5, "cheap viagra again", :spam)
    store = m.store
    before = store.table(:spam).size + store.table(:ham).size
    dropped = store.prune(2)
    assert_operator dropped, :>, 0
    assert_equal before - dropped, store.table(:spam).size + store.table(:ham).size
    assert_equal store.table(:spam).values.inject(0, :+), m.stats[:spam_tokens]
    assert_equal store.table(:spam).size, m.stats[:spam_vocab]
    assert store.table(:spam).key?("w:cheap")       # seen 3 times
    assert !store.table(:spam).key?("w:pharmacy")   # seen once
  end

  def test_probability_does_not_overflow
    assert_equal 1.0, Splam::TextModel.probability(5000)
    assert_in_delta 0.0, Splam::TextModel.probability(-5000), 1e-300
  end
end

# needs a Redis (db 13) on localhost or REDIS_HOST; omitted without one
class TextModelRedisTest < Test::Unit::TestCase
  include TextModelTests

  def setup
    require 'redis'
    @redis = Redis.new(:host => ENV["REDIS_HOST"] || "127.0.0.1", :db => 13)
    @redis.ping
    @prefix = "splam:test:#{Process.pid}"
  rescue StandardError, LoadError
    omit("needs Redis on localhost:6379 or REDIS_HOST")
  end

  def teardown
    %w(spam ham meta labels).each { |k| @redis.del("#{@prefix}:#{k}") } if @redis && @prefix
  end

  def model
    Splam::TextModel.new(Splam::TextModel::RedisStore.new(@redis, @prefix))
  end

  def test_loads_a_memory_store
    mem = Splam::TextModel.new(Splam::TextModel::MemoryStore.new)
    train_a_little(mem)
    store = Splam::TextModel::RedisStore.new(@redis, @prefix)
    store.load(mem.store, 3)
    loaded = Splam::TextModel.new(store)
    assert_equal mem.stats, loaded.stats
    assert_in_delta mem.score("cheap viagra here")[:log_odds], loaded.score("cheap viagra here")[:log_odds], 1e-9
    assert_equal false, loaded.train(1, "buy cheap viagra pills now", :spam) # labels came too
    assert_equal store.keys.sort, store.keys.select { |k| @redis.exists(k) }.sort
  end

  def test_scores_with_one_lookup_per_label
    m = model
    train_a_little(m)
    assert_equal %w(meta ham spam labels).sort, %w(spam ham meta labels).select { |k| @redis.exists("#{@prefix}:#{k}") }.sort
  end
end
