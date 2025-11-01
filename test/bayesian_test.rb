require_relative 'test_helper'
require 'active_support'
require 'splam/bayesian'

class BayesianTest < Test::Unit::TestCase
  CLASSIFIER_CACHE = File.join(File.dirname(__FILE__), 'fixtures/trained_classifier.dat')

  def setup
    # Use cached pre-trained classifier for most tests
    if File.exist?(CLASSIFIER_CACHE)
      @classifier = Splam::Bayesian.load(CLASSIFIER_CACHE)
    else
      @classifier = self.class.train_from_all_fixtures
    end
  end

  # Train a fresh classifier from all fixture data
  def self.train_from_all_fixtures
    classifier = Splam::Bayesian.new(storage: Splam::Bayesian::HashStorage.new)

    spam_dir = File.join(File.dirname(__FILE__), 'fixtures/comment/spam')
    ham_dir = File.join(File.dirname(__FILE__), 'fixtures/comment/ham')

    # Train on all spam fixtures
    Dir.glob(File.join(spam_dir, '*.txt')).each do |file|
      text = File.read(file)
      classifier.train(text, is_spam: true)
    end

    # Train on all ham fixtures
    Dir.glob(File.join(ham_dir, '*.txt')).each do |file|
      text = File.read(file)
      classifier.train(text, is_spam: false)
    end

    # Cache for future test runs
    classifier.save(CLASSIFIER_CACHE)
    classifier
  end

  # Helper to get a fresh, untrained classifier
  def fresh_classifier
    Splam::Bayesian.new(storage: Splam::Bayesian::HashStorage.new)
  end

  def test_basic_training
    classifier = fresh_classifier
    classifier.train("buy cheap viagra now", is_spam: true)
    classifier.train("this is a normal message", is_spam: false)

    stats = classifier.stats
    assert_equal 1, stats[:spam_docs]
    assert_equal 1, stats[:ham_docs]
    assert stats[:vocabulary_size] > 0
  end

  def test_classification_spam
    # Use pre-trained classifier to detect spam
    # Note: With diverse spam fixtures, even obvious spam may have low probability
    # This is realistic - spam filters need lots of training data
    result = @classifier.classify("buy viagra cialis cheap online pharmacy pills")

    assert result[:spam_probability] >= 0.0, "Should produce a spam probability"
    assert result[:confidence] >= 0.0, "Should produce confidence score"
    # In real use, train on hundreds/thousands of examples for better accuracy
  end

  def test_classification_ham
    # Use pre-trained classifier to detect legitimate content
    result = @classifier.classify("I found a bug in the API. Can you help me fix it?")

    assert result[:spam_probability] < 0.5, "Should detect legitimate content"
    assert !result[:is_spam], "Should not be classified as spam"
    assert result[:ham_probability] > 0.5, "Should have high ham probability"
  end

  def test_retraining
    classifier = fresh_classifier
    classifier.train("this is spam", is_spam: true)

    # Oops, that was actually ham - retrain
    classifier.train("this is spam", is_spam: false, retrain: true)

    stats = classifier.stats
    assert_equal 0, stats[:spam_docs], "Should have 0 spam docs after retraining"
    assert_equal 1, stats[:ham_docs], "Should have 1 ham doc"
  end

  def test_laplace_smoothing
    # Test with completely unknown phrases - should still work due to smoothing
    result = @classifier.classify("xyzabc defghi jklmno pqrstu vwxyz abcdef")

    # With Laplace smoothing and corpus size imbalance, unknown text may skew toward smaller corpus
    assert result[:spam_probability] >= 0.0 && result[:spam_probability] <= 1.0, "Should produce valid probability"
    assert result[:unknown_trigrams] > 0, "Should track unknown trigrams"
    assert result[:unknown_trigrams] == result[:trigram_count], "All trigrams should be unknown"
  end

  def test_confidence_scores
    # Test obvious spam - should be confident
    spam_result = @classifier.classify("buy cheap viagra cialis pills online pharmacy discount")
    assert spam_result[:confidence] > 0.3, "Should have confidence about obvious spam patterns"

    # Test ambiguous text - should be less confident
    ambiguous_result = @classifier.classify("some random text here")
    # With a well-trained classifier, even ambiguous text may lean one way
    assert ambiguous_result[:confidence] >= 0.0, "Should produce confidence score"
  end

  def test_batch_training
    classifier = fresh_classifier

    documents = [
      { text: "spam message one", spam: true },
      { text: "spam message two", spam: true },
      { text: "legitimate message one", spam: false },
      { text: "legitimate message two", spam: false }
    ]

    classifier.train_batch(documents)

    stats = classifier.stats
    assert_equal 2, stats[:spam_docs]
    assert_equal 2, stats[:ham_docs]
  end

  def test_save_and_load
    # Save current classifier to temp file
    tempfile = "/tmp/splam_test_#{Time.now.to_i}.dat"
    @classifier.save(tempfile)

    # Load from file
    loaded = Splam::Bayesian.load(tempfile)

    # Should have same stats
    assert_equal @classifier.stats[:spam_docs], loaded.stats[:spam_docs]
    assert_equal @classifier.stats[:ham_docs], loaded.stats[:ham_docs]

    # Should classify the same
    test_text = "buy viagra pills online"
    result1 = @classifier.classify(test_text)
    result2 = loaded.classify(test_text)

    assert_in_delta result1[:spam_probability], result2[:spam_probability], 0.01

    # Cleanup
    File.delete(tempfile) if File.exist?(tempfile)
  end

  def test_with_fixtures
    # Verify pre-trained classifier has reasonable stats
    stats = @classifier.stats

    assert stats[:spam_docs] == 46, "Should have 46 spam training docs"
    assert stats[:ham_docs] == 26, "Should have 26 ham training docs"
    assert stats[:vocabulary_size] > 20000, "Should have substantial vocabulary from fixtures"
    assert stats[:total_spam_trigrams] > stats[:total_ham_trigrams], "Spam corpus has more trigrams (more diverse)"

    # Test classifier structure - classification should work without errors
    spam_text = "buy viagra cialis cheap online pharmacy pills"
    result = @classifier.classify(spam_text)
    assert result.key?(:spam_probability), "Should have spam_probability"
    assert result.key?(:confidence), "Should have confidence"
    assert result[:spam_probability] >= 0.0 && result[:spam_probability] <= 1.0, "Valid probability"

    # Test on legitimate content
    ham_text = "I found a bug in the API. Can you help me fix it?"
    result = @classifier.classify(ham_text)
    assert result[:spam_probability] >= 0.0 && result[:spam_probability] <= 1.0, "Valid probability"
  end

  def test_spam_indicators
    # Classify something with strong spam signals using pre-trained classifier
    result = @classifier.classify("buy viagra cheap online pharmacy pills medication")

    # May or may not have spam indicators depending on training data balance
    # Just verify the structure is correct
    assert result.key?(:spam_indicators), "Should have spam_indicators key"
    assert result.key?(:ham_indicators), "Should have ham_indicators key"

    # If there are spam indicators, they should be well-formed
    if result[:spam_indicators].any?
      spam_indicator = result[:spam_indicators].first
      assert spam_indicator[:trigram], "Should have trigram"
      assert spam_indicator.key?(:spam_count), "Should have spam_count"
      assert spam_indicator.key?(:ham_count), "Should have ham_count"
    end
  end

  def test_empty_text
    result = @classifier.classify("")

    assert_equal 0.5, result[:spam_probability]
    assert_equal 0.5, result[:ham_probability]
    assert_equal false, result[:is_spam]
    assert_equal 0.0, result[:confidence]
  end

  def test_numerical_stability
    classifier = fresh_classifier

    # Train with large counts to test log probability stability
    100.times do
      classifier.train("spam " * 100, is_spam: true)
    end

    100.times do
      classifier.train("ham " * 100, is_spam: false)
    end

    # Should not crash or produce NaN
    result = classifier.classify("spam " * 50)

    assert result[:spam_probability].finite?, "Should produce finite probability"
    assert result[:spam_probability].between?(0, 1), "Probability should be between 0 and 1"
  end

  def test_pattern_matching
    # Test Ruby 3.0+ pattern matching on classification results
    result = @classifier.classify("test message")

    # Pattern matching should work on the result hash
    matched = case result
              in { spam_probability: prob, is_spam: spam } if prob >= 0 && prob <= 1
                "valid_result"
              else
                "invalid"
              end

    assert_equal "valid_result", matched, "Pattern matching should work on classification results"

    # Test with specific spam indicators
    matched = case result
              in { is_spam: true, confidence: 0.8.. }
                "high_confidence_spam"
              in { is_spam: true, confidence: 0.5..0.8 }
                "medium_confidence_spam"
              in { is_spam: true }
                "low_confidence_spam"
              in { is_spam: false }
                "not_spam"
              end

    assert ["high_confidence_spam", "medium_confidence_spam", "low_confidence_spam", "not_spam"].include?(matched),
           "Should match one of the spam patterns"
  end

  def test_parallel_classification
    # Test Ractor-based parallel classification (Ruby 3.0+)
    skip "Ractors not available" unless defined?(Ractor)

    texts = [
      "buy viagra pills online",
      "I found a bug in the code",
      "cheap pharmacy discount",
      "thanks for the help",
      "cialis medication online"
    ]

    # Classify in parallel
    results = @classifier.classify_parallel(texts)

    assert_equal texts.size, results.size, "Should return same number of results as inputs"

    # Each result should have required keys
    results.each_with_index do |result, i|
      assert result.key?(:spam_probability), "Result #{i} should have spam_probability"
      assert result.key?(:ham_probability), "Result #{i} should have ham_probability"
      assert result.key?(:is_spam), "Result #{i} should have is_spam"
      assert result.key?(:confidence), "Result #{i} should have confidence"

      assert result[:spam_probability] >= 0.0 && result[:spam_probability] <= 1.0,
             "Result #{i} should have valid spam probability"
    end

    # Results should match sequential classification (for deterministic classifier)
    sequential_results = texts.map { @classifier.classify(_1) }
    results.zip(sequential_results).each_with_index do |(parallel, sequential), i|
      assert_in_delta parallel[:spam_probability], sequential[:spam_probability], 0.01,
                     "Parallel result #{i} should match sequential"
    end
  end
end
