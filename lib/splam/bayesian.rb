# encoding: UTF-8
#
# Enhanced Bayesian spam filter using trigram analysis
# Implements proper Naive Bayes classification with Laplace smoothing
#
require_relative 'ngram'

class Splam::Bayesian
  attr_reader :site_id, :storage

  # Laplace smoothing parameter (alpha)
  # Higher = more conservative (less sensitive to rare trigrams)
  # Lower values (0.01-0.1) work better with unbalanced corpus sizes
  DEFAULT_ALPHA = 0.01

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
    if retrain
      @storage.decrement_doc_count(!is_spam, @site_id)
    end
    @storage.increment_doc_count(is_spam, @site_id)
  end

  # Classify a document using Naive Bayes
  # @param text [String] the document to classify
  # @return [ClassificationResult] classification result with probabilities and details
  #
  # Example with pattern matching (Ruby 3.0+):
  #   case classifier.classify(text)
  #   in { is_spam: true, confidence: 0.8.. }
  #     puts "High confidence spam!"
  #   in { is_spam: true }
  #     puts "Likely spam"
  #   in { is_spam: false }
  #     puts "Not spam"
  #   end
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
      spam_indicators: spam_indicators.sort_by { -_1[:ratio] }.first(5),
      ham_indicators: ham_indicators.sort_by { -_1[:ratio] }.first(5),
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

  # Classify multiple documents in parallel using Ractors (Ruby 3.0+)
  # @param texts [Array<String>] array of documents to classify
  # @param workers [Integer] number of parallel workers (default: CPU count)
  # @return [Array<Hash>] array of classification results
  #
  # Example:
  #   texts = ["spam text 1", "ham text 2", "spam text 3"]
  #   results = classifier.classify_parallel(texts)
  #   results.each_with_index do |result, i|
  #     puts "Text #{i}: #{result[:is_spam] ? 'SPAM' : 'HAM'}"
  #   end
  def classify_parallel(texts, workers: nil)
    # Fall back to sequential if Ractor not available or single text
    return texts.map { classify(_1) } if !defined?(Ractor) || texts.size == 1

    workers ||= [Ractor.count, texts.size].min
    workers = [workers, texts.size].min

    # For HashStorage, we need to make the data ractor-safe
    if @storage.is_a?(HashStorage)
      # Serialize storage data for Ractor sharing
      storage_data = {
        spam_trigrams: @storage.spam_trigrams.dup,
        ham_trigrams: @storage.ham_trigrams.dup,
        spam_docs: @storage.spam_docs,
        ham_docs: @storage.ham_docs,
        alpha: @alpha
      }

      # Create Ractors to process batches
      batch_size = (texts.size.to_f / workers).ceil
      ractors = texts.each_slice(batch_size).map do |batch|
        Ractor.new(batch, storage_data) do |texts_batch, data|
          # Inline trigram extraction (can't use Ngram class due to global variable access)
          def self.extract_trigrams(text)
            # Use scan instead of split to avoid global variable access
            words = text.downcase.gsub("'", "").scan(/[a-z0-9]+/)
            hash = Hash.new(0)
            i = 0
            while (i < words.length)
              tri = []
              count = 0
              while ((words.length > i + count) && (tri.length < 3))
                word = words[i + count]
                tri << words[i + count] if word && word != ""
                count += 1
              end
              hash[tri.join(' ')] += 1 if tri.length == 3
              i += 1
            end
            hash
          end

          # Simple classifier for parallel processing
          texts_batch.map do |text|
            trigrams = extract_trigrams(text)

            if trigrams.empty?
              {
                spam_probability: 0.5,
                ham_probability: 0.5,
                is_spam: false,
                confidence: 0.0
              }
            else
              spam_docs = data[:spam_docs]
              ham_docs = data[:ham_docs]
              total_docs = spam_docs + ham_docs

              prior_spam = spam_docs.to_f / total_docs
              prior_ham = ham_docs.to_f / total_docs

              log_prob_spam = Math.log(prior_spam)
              log_prob_ham = Math.log(prior_ham)

              vocab_size = (data[:spam_trigrams].keys + data[:ham_trigrams].keys).uniq.size
              total_spam = data[:spam_trigrams].values.sum
              total_ham = data[:ham_trigrams].values.sum
              alpha = data[:alpha]

              trigrams.each do |trigram, count|
                next if trigram.nil? || trigram.strip.empty?

                spam_count = data[:spam_trigrams][trigram] || 0
                ham_count = data[:ham_trigrams][trigram] || 0

                prob_spam = (spam_count + alpha) / (total_spam + alpha * vocab_size).to_f
                prob_ham = (ham_count + alpha) / (total_ham + alpha * vocab_size).to_f

                log_prob_spam += Math.log(prob_spam) * count
                log_prob_ham += Math.log(prob_ham) * count
              end

              max_log = [log_prob_spam, log_prob_ham].max
              exp_spam = Math.exp(log_prob_spam - max_log)
              exp_ham = Math.exp(log_prob_ham - max_log)

              prob_spam = exp_spam / (exp_spam + exp_ham)
              prob_ham = exp_ham / (exp_spam + exp_ham)

              {
                spam_probability: prob_spam,
                ham_probability: prob_ham,
                is_spam: prob_spam > 0.5,
                confidence: (prob_spam - 0.5).abs * 2
              }
            end
          end
        end
      end

      # Collect results from all Ractors
      ractors.flat_map(&:take)
    else
      # Redis storage - not ractor-safe, fall back to sequential
      texts.map { classify(_1) }
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

  # Get classifier statistics (Ruby 3.1 hash shorthand)
  def stats
    site_id = @site_id
    spam_docs = @storage.spam_doc_count(@site_id)
    ham_docs = @storage.ham_doc_count(@site_id)
    vocabulary_size = @storage.vocabulary_size(@site_id)
    total_spam_trigrams = @storage.total_spam_trigrams(@site_id)
    total_ham_trigrams = @storage.total_ham_trigrams(@site_id)
    alpha = @alpha

    { site_id:, spam_docs:, ham_docs:, vocabulary_size:, total_spam_trigrams:, total_ham_trigrams:, alpha: }
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

    # Endless method definitions (Ruby 3.0+)
    def spam_key(site_id = nil) = site_id ? "splam:spam:#{site_id}" : "splam:spam"
    def ham_key(site_id = nil) = site_id ? "splam:ham:#{site_id}" : "splam:ham"
    def meta_key(site_id = nil) = site_id ? "splam:meta:#{site_id}" : "splam:meta"

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

    def spam_trigram_count(trigram, site_id = nil) = @redis.hget(spam_key(site_id), trigram).to_i
    def ham_trigram_count(trigram, site_id = nil) = @redis.hget(ham_key(site_id), trigram).to_i

    def increment_doc_count(is_spam, site_id = nil)
      field = is_spam ? "spam_docs" : "ham_docs"
      @redis.hincrby(meta_key(site_id), field, 1)
    end

    def decrement_doc_count(is_spam, site_id = nil)
      field = is_spam ? "spam_docs" : "ham_docs"
      @redis.hincrby(meta_key(site_id), field, -1)
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

    def decrement_doc_count(is_spam, site_id = nil)
      if is_spam
        @spam_docs -= 1
        @spam_docs = 0 if @spam_docs < 0
      else
        @ham_docs -= 1
        @ham_docs = 0 if @ham_docs < 0
      end
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
