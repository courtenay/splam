require_relative 'test_helper'
require 'active_support'

class BayesianTest < Test::Unit::TestCase
  def setup
    # Use hash storage for testing (no Redis dependency)
    @classifier = Splam::Bayesian.new(storage: Splam::Bayesian::HashStorage.new)
  end

  def test_basic_training
    @classifier.train("buy cheap viagra now", is_spam: true)
    @classifier.train("this is a normal message", is_spam: false)

    stats = @classifier.stats
    assert_equal 1, stats[:spam_docs]
    assert_equal 1, stats[:ham_docs]
    assert stats[:vocabulary_size] > 0
  end

  def test_classification_spam
    # Train with obvious spam
    5.times do
      @classifier.train("buy viagra pills cheap pharmacy online", is_spam: true)
      @classifier.train("cialis medication purchase now discount", is_spam: true)
    end

    # Train with obvious ham
    5.times do
      @classifier.train("hey thanks for the bug report", is_spam: false)
      @classifier.train("I found a problem with the api", is_spam: false)
    end

    # Test spam detection
    result = @classifier.classify("buy cheap viagra online pharmacy")

    assert result[:spam_probability] > 0.5, "Should detect spam"
    assert result[:is_spam], "Should be classified as spam"
    assert result[:spam_indicators].any?, "Should have spam indicators"
  end

  def test_classification_ham
    # Train
    5.times do
      @classifier.train("buy viagra pills", is_spam: true)
    end

    5.times do
      @classifier.train("found a bug in the api endpoint", is_spam: false)
      @classifier.train("thanks for fixing that issue", is_spam: false)
    end

    # Test ham detection
    result = @classifier.classify("I found a bug with the new api")

    assert result[:spam_probability] < 0.5, "Should detect ham"
    assert !result[:is_spam], "Should not be classified as spam"
    assert result[:ham_probability] > 0.5, "Should have high ham probability"
  end

  def test_retraining
    @classifier.train("this is spam", is_spam: true)

    # Oops, that was actually ham - retrain
    @classifier.train("this is spam", is_spam: false, retrain: true)

    stats = @classifier.stats
    assert_equal 0, stats[:spam_docs], "Should have 0 spam docs after retraining"
    assert_equal 1, stats[:ham_docs], "Should have 1 ham doc"
  end

  def test_laplace_smoothing
    # Train with minimal data
    @classifier.train("known spam phrase", is_spam: true)
    @classifier.train("known ham phrase", is_spam: false)

    # Test with unknown phrases - should still work due to smoothing
    result = @classifier.classify("completely unknown words here")

    assert result[:spam_probability].between?(0.4, 0.6), "Unknown text should be uncertain"
    assert result[:unknown_trigrams] > 0, "Should track unknown trigrams"
  end

  def test_confidence_scores
    # Train with clear examples
    10.times do
      @classifier.train("obvious spam with viagra and cialis pills", is_spam: true)
    end

    10.times do
      @classifier.train("normal discussion about programming", is_spam: false)
    end

    # Test obvious spam - should be confident
    spam_result = @classifier.classify("spam viagra cialis pills pharmacy")
    assert spam_result[:confidence] > 0.7, "Should be confident about obvious spam"

    # Test ambiguous text - should be less confident
    ambiguous_result = @classifier.classify("some random text")
    assert ambiguous_result[:confidence] < 0.5, "Should be uncertain about ambiguous text"
  end

  def test_batch_training
    documents = [
      { text: "spam message one", spam: true },
      { text: "spam message two", spam: true },
      { text: "legitimate message one", spam: false },
      { text: "legitimate message two", spam: false }
    ]

    @classifier.train_batch(documents)

    stats = @classifier.stats
    assert_equal 2, stats[:spam_docs]
    assert_equal 2, stats[:ham_docs]
  end

  def test_save_and_load
    # Train classifier
    @classifier.train("spam content here", is_spam: true)
    @classifier.train("ham content here", is_spam: false)

    # Save to file
    tempfile = "/tmp/splam_test_#{Time.now.to_i}.dat"
    @classifier.save(tempfile)

    # Load from file
    loaded = Splam::Bayesian.load(tempfile)

    # Should have same stats
    assert_equal @classifier.stats[:spam_docs], loaded.stats[:spam_docs]
    assert_equal @classifier.stats[:ham_docs], loaded.stats[:ham_docs]

    # Should classify the same
    result1 = @classifier.classify("spam content")
    result2 = loaded.classify("spam content")

    assert_in_delta result1[:spam_probability], result2[:spam_probability], 0.01

    # Cleanup
    File.delete(tempfile) if File.exist?(tempfile)
  end

  def test_with_fixtures
    # Train from actual test fixtures
    classifier = Splam::Bayesian.new(storage: Splam::Bayesian::HashStorage.new)

    spam_dir = File.join(File.dirname(__FILE__), 'fixtures/comment/spam')
    ham_dir = File.join(File.dirname(__FILE__), 'fixtures/comment/ham')

    # Train on spam fixtures
    spam_count = 0
    Dir.glob(File.join(spam_dir, '*.txt')).first(10).each do |file|
      text = File.read(file)
      classifier.train(text, is_spam: true)
      spam_count += 1
    end

    # Train on ham fixtures
    ham_count = 0
    Dir.glob(File.join(ham_dir, '*.txt')).first(10).each do |file|
      text = File.read(file)
      classifier.train(text, is_spam: false)
      ham_count += 1
    end

    assert spam_count > 0, "Should have trained on spam"
    assert ham_count > 0, "Should have trained on ham"

    # Test on known spam
    spam_text = "buy viagra cialis cheap online pharmacy pills"
    result = classifier.classify(spam_text)
    assert result[:spam_probability] > 0.4, "Should detect pharmaceutical spam"

    # Test on known ham
    ham_text = "I found a bug in the API. Can you help me fix it?"
    result = classifier.classify(ham_text)
    assert result[:spam_probability] < 0.6, "Should detect legitimate content"
  end

  def test_spam_indicators
    # Train with specific patterns
    @classifier.train("buy viagra cheap pharmacy online pills medication", is_spam: true)
    @classifier.train("buy viagra cheap pharmacy online pills medication", is_spam: true)
    @classifier.train("buy viagra cheap pharmacy online pills medication", is_spam: true)

    @classifier.train("thanks for the help with the bug", is_spam: false)

    # Classify something with strong spam signals
    result = @classifier.classify("buy viagra cheap online pharmacy")

    assert result[:spam_indicators].any?, "Should have spam indicators"

    # Check that indicators make sense
    spam_indicator = result[:spam_indicators].first
    assert spam_indicator[:spam_count] > spam_indicator[:ham_count], "Spam count should be higher"
    assert spam_indicator[:trigram], "Should have trigram"
  end

  def test_empty_text
    result = @classifier.classify("")

    assert_equal 0.5, result[:spam_probability]
    assert_equal 0.5, result[:ham_probability]
    assert_equal false, result[:is_spam]
    assert_equal 0.0, result[:confidence]
  end

  def test_numerical_stability
    # Train with large counts to test log probability stability
    100.times do
      @classifier.train("spam " * 100, is_spam: true)
    end

    100.times do
      @classifier.train("ham " * 100, is_spam: false)
    end

    # Should not crash or produce NaN
    result = @classifier.classify("spam " * 50)

    assert result[:spam_probability].finite?, "Should produce finite probability"
    assert result[:spam_probability].between?(0, 1), "Probability should be between 0 and 1"
  end
end
