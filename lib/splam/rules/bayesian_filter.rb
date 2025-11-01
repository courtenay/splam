# Bayesian spam filtering rule using trigram analysis
class Splam::Rules::BayesianFilter < Splam::Rule
  class << self
    attr_accessor :classifier, :auto_train

    # Initialize classifier on first use
    def initialize_classifier(site_id = nil)
      require_relative '../bayesian'

      @classifier ||= {}
      @classifier[site_id] ||= Splam::Bayesian.new(site_id: site_id)
    end

    # Train from fixtures (call during app initialization)
    def train_from_fixtures!(site_id = nil)
      initialize_classifier(site_id)

      spam_dir = File.join(File.dirname(__FILE__), '../../test/fixtures/comment/spam')
      ham_dir = File.join(File.dirname(__FILE__), '../../test/fixtures/comment/ham')

      # Train on spam
      Dir.glob(File.join(spam_dir, '*.txt')).each do |file|
        text = File.read(file)
        @classifier[site_id].train(text, is_spam: true)
      end

      # Train on ham
      Dir.glob(File.join(ham_dir, '*.txt')).each do |file|
        text = File.read(file)
        @classifier[site_id].train(text, is_spam: false)
      end

      puts "Bayesian filter trained: #{@classifier[site_id].stats.inspect}"
    end

    # Get classifier for site
    def get_classifier(site_id = nil)
      initialize_classifier(site_id) unless @classifier && @classifier[site_id]
      @classifier[site_id]
    end
  end

  def run
    site_id = @suite.respond_to?(:site_id) ? @suite.site_id : nil
    classifier = self.class.get_classifier(site_id)

    # Skip if classifier not trained
    stats = classifier.stats
    if stats[:spam_docs].zero? && stats[:ham_docs].zero?
      add_score 0, "Bayesian filter not trained"
      return
    end

    # Classify the content
    result = classifier.classify(@body)

    # Convert probability to score
    if result[:spam_probability] > 0.5
      # Spam probability from 0.5 to 1.0 maps to 0 to 200 points
      score = ((result[:spam_probability] - 0.5) * 400).to_i
      confidence = (result[:confidence] * 100).round

      # Build reason string
      reason = "Bayesian: #{(result[:spam_probability] * 100).round}% spam"
      reason += " (#{confidence}% confident)"

      # Add top spam indicators
      if result[:spam_indicators].any?
        top_indicators = result[:spam_indicators].first(3).map { |i| i[:trigram] }
        reason += " [#{top_indicators.join(', ')}]"
      end

      add_score score, reason

    elsif result[:spam_probability] < 0.3
      # Strong ham signal - reduce score
      score = ((0.5 - result[:spam_probability]) * 200).to_i
      confidence = (result[:confidence] * 100).round

      reason = "Bayesian: #{(result[:ham_probability] * 100).round}% ham"
      reason += " (#{confidence}% confident)"

      add_score -score, reason

    else
      # Uncertain (0.3 to 0.5)
      add_score 0, "Bayesian: uncertain (#{(result[:spam_probability] * 100).round}% spam)"
    end

    # Warn if too many unknown trigrams
    if result[:unknown_trigrams] > result[:trigram_count] * 0.8
      add_score 10, "Bayesian: #{result[:unknown_trigrams]}/#{result[:trigram_count]} unknown trigrams"
    end
  end

  # Hook to train on feedback (call this when user marks spam/ham)
  def self.record_feedback(text, is_spam:, site_id: nil)
    classifier = get_classifier(site_id)
    classifier.train(text, is_spam: is_spam, retrain: true)

    # Clear caches if using Redis
    if classifier.storage.respond_to?(:clear_cache)
      classifier.storage.clear_cache(site_id)
    end
  end
end
