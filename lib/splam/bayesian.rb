# encoding: UTF-8
#
# Enhanced Bayesian spam filter using trigram analysis
# Implements proper Naive Bayes classification with Laplace smoothing
#
class Splam::Bayesian
  attr_reader :site_id, :storage

  # Laplace smoothing parameter (alpha)
  # Higher = more conservative (less sensitive to rare trigrams)
  DEFAULT_ALPHA = 1.0

  # Probability threshold for spam classification
  DEFAULT_THRESHOLD = 0.5

  def initialize(site_id: nil, storage: nil, alpha: DEFAULT_ALPHA)
    @site_id = site_id
    @storage = storage || (defined?(REDIS) ? RedisStorage.new : HashStorage.new)
    @alpha = alpha
  end

  # Train the classifier with a document
  # @param text [String] the document text
  # @param is_spam [Boolean] true if spam, false if ham
  # @param retrain [Boolean] if true, removes from opposite category (for corrections)
  def train(text, is_spam: false, retrain: false)
    trigrams = Splam::Ngram.trigram(text)

    trigrams.each do |trigram, count|
      next if trigram.nil? || trigram.strip.empty?

      if is_spam
        @storage.increment_spam(trigram, count, @site_id)
        @storage.decrement_ham(trigram, count, @site_id) if retrain
      else
        @storage.increment_ham(trigram, count, @site_id)
        @storage.decrement_spam(trigram, count, @site_id) if retrain
      end
    end

    # Update document counts
    @storage.increment_doc_count(is_spam, @site_id)
  end

  # Classify a document using Naive Bayes
  # @param text [String] the document to classify
  # @return [Hash] classification result with probabilities and details
  def classify(text)
    trigrams = Splam::Ngram.trigram(text)

    return neutral_result if trigrams.empty?

    # Get prior probabilities P(spam) and P(ham)
    spam_docs = @storage.spam_doc_count(@site_id)
    ham_docs = @storage.ham_doc_count(@site_id)
    total_docs = spam_docs + ham_docs

    return neutral_result if total_docs.zero?

    # Prior probabilities
    prior_spam = spam_docs.to_f / total_docs
    prior_ham = ham_docs.to_f / total_docs

    # Calculate log probabilities for numerical stability
    # log P(spam|text) = log P(spam) + sum(log P(trigram|spam))
    log_prob_spam = Math.log(prior_spam)
    log_prob_ham = Math.log(prior_ham)

    # Get vocabulary size for Laplace smoothing
    vocab_size = @storage.vocabulary_size(@site_id)

    # Total trigram counts in each category
    total_spam_trigrams = @storage.total_spam_trigrams(@site_id)
    total_ham_trigrams = @storage.total_ham_trigrams(@site_id)

    # Track individual contributions for explainability
    spam_indicators = []
    ham_indicators = []

    trigrams.each do |trigram, count|
      next if trigram.nil? || trigram.strip.empty?

      # Get trigram counts
      spam_count = @storage.spam_trigram_count(trigram, @site_id)
      ham_count = @storage.ham_trigram_count(trigram, @site_id)

      # Laplace smoothing: P(trigram|category) = (count + alpha) / (total + alpha * vocab)
      prob_trigram_given_spam = (spam_count + @alpha) / (total_spam_trigrams + @alpha * vocab_size).to_f
      prob_trigram_given_ham = (ham_count + @alpha) / (total_ham_trigrams + @alpha * vocab_size).to_f

      # Add to log probabilities (multiply in log space = add)
      contribution_spam = Math.log(prob_trigram_given_spam) * count
      contribution_ham = Math.log(prob_trigram_given_ham) * count

      log_prob_spam += contribution_spam
      log_prob_ham += contribution_ham

      # Track significant indicators
      if spam_count > ham_count * 2 && spam_count > 2
        spam_indicators << {
          trigram: trigram,
          spam_count: spam_count,
          ham_count: ham_count,
          ratio: spam_count.to_f / (ham_count + 1)
        }
      elsif ham_count > spam_count * 2 && ham_count > 2
        ham_indicators << {
          trigram: trigram,
          spam_count: spam_count,
          ham_count: ham_count,
          ratio: ham_count.to_f / (spam_count + 1)
        }
      end
    end

    # Convert log probabilities back to probabilities
    # Use log-sum-exp trick for numerical stability
    max_log_prob = [log_prob_spam, log_prob_ham].max
    exp_spam = Math.exp(log_prob_spam - max_log_prob)
    exp_ham = Math.exp(log_prob_ham - max_log_prob)

    prob_spam = exp_spam / (exp_spam + exp_ham)
    prob_ham = exp_ham / (exp_spam + exp_ham)

    # Calculate confidence (distance from 0.5)
    confidence = (prob_spam - 0.5).abs * 2

    {
      spam_probability: prob_spam,
      ham_probability: prob_ham,
      is_spam: prob_spam > DEFAULT_THRESHOLD,
      confidence: confidence,
      spam_indicators: spam_indicators.sort_by { |i| -i[:ratio] }.first(5),
      ham_indicators: ham_indicators.sort_by { |i| -i[:ratio] }.first(5),
      trigram_count: trigrams.size,
      unknown_trigrams: trigrams.count { |t, _|
        @storage.spam_trigram_count(t, @site_id).zero? &&
        @storage.ham_trigram_count(t, @site_id).zero?
      }
    }
  end

  # Batch train from multiple documents
  def train_batch(documents)
    documents.each do |doc|
      train(doc[:text], is_spam: doc[:spam])
    end
  end

  # Train from test fixtures
  def self.train_from_fixtures(site_id: nil)
    classifier = new(site_id: site_id)

    # Load spam examples
    spam_files = Dir.glob(File.join(File.dirname(__FILE__), '../../test/fixtures/comment/spam/*.txt'))
    spam_files.each do |file|
      text = File.read(file)
      classifier.train(text, is_spam: true)
    end

    # Load ham examples
    ham_files = Dir.glob(File.join(File.dirname(__FILE__), '../../test/fixtures/comment/ham/*.txt'))
    ham_files.each do |file|
      text = File.read(file)
      classifier.train(text, is_spam: false)
    end

    classifier
  end

  # Save classifier to file (for file-based storage)
  def save(filename)
    @storage.save(filename, @site_id) if @storage.respond_to?(:save)
  end

  # Load classifier from file
  def self.load(filename, site_id: nil)
    storage = HashStorage.load(filename)
    new(site_id: site_id, storage: storage)
  end

  # Get classifier statistics
  def stats
    {
      site_id: @site_id,
      spam_docs: @storage.spam_doc_count(@site_id),
      ham_docs: @storage.ham_doc_count(@site_id),
      vocabulary_size: @storage.vocabulary_size(@site_id),
      total_spam_trigrams: @storage.total_spam_trigrams(@site_id),
      total_ham_trigrams: @storage.total_ham_trigrams(@site_id),
      alpha: @alpha
    }
  end

  private

  def neutral_result
    {
      spam_probability: 0.5,
      ham_probability: 0.5,
      is_spam: false,
      confidence: 0.0,
      spam_indicators: [],
      ham_indicators: [],
      trigram_count: 0,
      unknown_trigrams: 0
    }
  end

  # Redis-based storage backend
  class RedisStorage
    def initialize(redis = defined?(REDIS) ? REDIS : nil)
      @redis = redis
      raise "Redis not available" unless @redis
    end

    def spam_key(site_id = nil)
      site_id ? "splam:spam:#{site_id}" : "splam:spam"
    end

    def ham_key(site_id = nil)
      site_id ? "splam:ham:#{site_id}" : "splam:ham"
    end

    def meta_key(site_id = nil)
      site_id ? "splam:meta:#{site_id}" : "splam:meta"
    end

    def increment_spam(trigram, count, site_id = nil)
      @redis.hincrby(spam_key(site_id), trigram, count)
    end

    def increment_ham(trigram, count, site_id = nil)
      @redis.hincrby(ham_key(site_id), trigram, count)
    end

    def decrement_spam(trigram, count, site_id = nil)
      @redis.hincrby(spam_key(site_id), trigram, -count)
    end

    def decrement_ham(trigram, count, site_id = nil)
      @redis.hincrby(ham_key(site_id), trigram, -count)
    end

    def spam_trigram_count(trigram, site_id = nil)
      @redis.hget(spam_key(site_id), trigram).to_i
    end

    def ham_trigram_count(trigram, site_id = nil)
      @redis.hget(ham_key(site_id), trigram).to_i
    end

    def increment_doc_count(is_spam, site_id = nil)
      field = is_spam ? "spam_docs" : "ham_docs"
      @redis.hincrby(meta_key(site_id), field, 1)
    end

    def spam_doc_count(site_id = nil)
      @redis.hget(meta_key(site_id), "spam_docs").to_i
    end

    def ham_doc_count(site_id = nil)
      @redis.hget(meta_key(site_id), "ham_docs").to_i
    end

    def total_spam_trigrams(site_id = nil)
      # Cache this as it's expensive
      cached = @redis.hget(meta_key(site_id), "total_spam_trigrams").to_i
      return cached if cached > 0

      total = @redis.hvals(spam_key(site_id)).map(&:to_i).sum
      @redis.hset(meta_key(site_id), "total_spam_trigrams", total)
      total
    end

    def total_ham_trigrams(site_id = nil)
      cached = @redis.hget(meta_key(site_id), "total_ham_trigrams").to_i
      return cached if cached > 0

      total = @redis.hvals(ham_key(site_id)).map(&:to_i).sum
      @redis.hset(meta_key(site_id), "total_ham_trigrams", total)
      total
    end

    def vocabulary_size(site_id = nil)
      # Union of spam and ham trigrams
      cached = @redis.hget(meta_key(site_id), "vocab_size").to_i
      return cached if cached > 0

      spam_keys = @redis.hkeys(spam_key(site_id))
      ham_keys = @redis.hkeys(ham_key(site_id))
      size = (spam_keys + ham_keys).uniq.size

      @redis.hset(meta_key(site_id), "vocab_size", size)
      size
    end

    def clear_cache(site_id = nil)
      @redis.hdel(meta_key(site_id), "total_spam_trigrams", "total_ham_trigrams", "vocab_size")
    end
  end

  # Hash-based storage (for deployments without Redis)
  class HashStorage
    attr_reader :spam_trigrams, :ham_trigrams, :spam_docs, :ham_docs

    def initialize
      @spam_trigrams = Hash.new(0)
      @ham_trigrams = Hash.new(0)
      @spam_docs = 0
      @ham_docs = 0
      @cache = {}
    end

    def increment_spam(trigram, count, site_id = nil)
      @spam_trigrams[trigram] += count
      clear_cache
    end

    def increment_ham(trigram, count, site_id = nil)
      @ham_trigrams[trigram] += count
      clear_cache
    end

    def decrement_spam(trigram, count, site_id = nil)
      @spam_trigrams[trigram] -= count
      @spam_trigrams[trigram] = 0 if @spam_trigrams[trigram] < 0
      clear_cache
    end

    def decrement_ham(trigram, count, site_id = nil)
      @ham_trigrams[trigram] -= count
      @ham_trigrams[trigram] = 0 if @ham_trigrams[trigram] < 0
      clear_cache
    end

    def spam_trigram_count(trigram, site_id = nil)
      @spam_trigrams[trigram]
    end

    def ham_trigram_count(trigram, site_id = nil)
      @ham_trigrams[trigram]
    end

    def increment_doc_count(is_spam, site_id = nil)
      is_spam ? @spam_docs += 1 : @ham_docs += 1
    end

    def spam_doc_count(site_id = nil)
      @spam_docs
    end

    def ham_doc_count(site_id = nil)
      @ham_docs
    end

    def total_spam_trigrams(site_id = nil)
      @cache[:total_spam] ||= @spam_trigrams.values.sum
    end

    def total_ham_trigrams(site_id = nil)
      @cache[:total_ham] ||= @ham_trigrams.values.sum
    end

    def vocabulary_size(site_id = nil)
      @cache[:vocab_size] ||= (@spam_trigrams.keys + @ham_trigrams.keys).uniq.size
    end

    def clear_cache
      @cache = {}
    end

    # Serialize to file
    def save(filename, site_id = nil)
      data = {
        spam_trigrams: @spam_trigrams,
        ham_trigrams: @ham_trigrams,
        spam_docs: @spam_docs,
        ham_docs: @ham_docs,
        site_id: site_id,
        version: 1
      }

      File.write(filename, Marshal.dump(data))
    end

    # Deserialize from file
    def self.load(filename)
      data = Marshal.load(File.read(filename))

      storage = new
      storage.instance_variable_set(:@spam_trigrams, data[:spam_trigrams])
      storage.instance_variable_set(:@ham_trigrams, data[:ham_trigrams])
      storage.instance_variable_set(:@spam_docs, data[:spam_docs])
      storage.instance_variable_set(:@ham_docs, data[:ham_docs])

      storage
    end
  end
end
