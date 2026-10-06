require File.expand_path('test_helper', File.dirname(__FILE__))

class ConfigTest < Test::Unit::TestCase
  class Flat < Splam::Rule
    def run
      add_score 10, "flat ten"
    end
  end
  Splam::Rule.default_rules.delete Flat

  class OptIn < Splam::Rule
    def self.opt_in?; true; end
    def run
      add_score 7, "opt-in seven"
    end
  end

  def teardown
    Splam.reset_config!
    Splam::Rules::BadWords.bad_word_score = nil
  end

  # a model class defined now, so its suite sees the current config
  def model(&rules)
    Class.new do
      include ::Splam
      attr_accessor :body
      splammable(:body, 100, &rules)
    end
  end

  def score(klass, body)
    r = klass.new
    r.body = body
    r.splam_score
  end

  def test_default_profile
    assert_equal :default, Splam.config.profile
    assert_equal 10, Splam::Rules::BadWords.bad_word_score
    assert !Splam.config.feature?(:lighthouse_words)
  end

  def test_unknown_profile
    assert_raise(ArgumentError) { Splam.configure { |c| c.profile = :nope } }
  end

  def test_lighthouse_profile_presets
    Splam.configure { |c| c.profile = :lighthouse }
    assert_equal 15, Splam::Rules::BadWords.bad_word_score
    assert Splam.config.feature?(:lighthouse_words)
    assert Splam.config.rule_enabled?(Splam::Rules::Fuzz)
  end

  def test_bad_word_score_overrides
    Splam.configure { |c| c.profile = :lighthouse; c.bad_word_score = 12 }
    assert_equal 12, Splam::Rules::BadWords.bad_word_score
    Splam::Rules::BadWords.bad_word_score = 3
    assert_equal 3, Splam::Rules::BadWords.bad_word_score
  end

  def test_opt_in_rules_only_with_their_profile
    assert !model.splam_suites[0].rules.key?(OptIn)
    assert !model.splam_suites[0].rules.key?(Splam::Rules::LineLength)
    Splam::Config::PROFILES[:test_opt_in] = { :bad_word_score => 10, :rules => [:opt_in], :features => [] }
    Splam.configure { |c| c.profile = :test_opt_in }
    assert model.splam_suites[0].rules.key?(OptIn)
  ensure
    Splam::Config::PROFILES.delete(:test_opt_in)
  end

  def test_a_suite_can_name_an_opt_in_rule
    klass = model { |s| s.rules = [OptIn] }
    assert_equal 7, score(klass, "anything")
  end

  def test_config_weights_apply_to_rules_without_one
    Splam.configure { |c| c.weights = { :flat => 3 } }
    assert_equal 30, score(model { |s| s.rules = [Flat] }, "x")
    # a weight named in the suite wins
    assert_equal 20, score(model { |s| s.rules = { Flat => 2 } }, "x")
  end

  def test_fractional_weights_count
    Splam.configure { |c| c.weights = { :flat => 0.5 } }
    assert_equal 5, score(model { |s| s.rules = [Flat] }, "x")
  end

  def test_lighthouse_words_only_in_their_profile
    klass = model { |s| s.rules = [:bad_words] }
    assert_equal 0, score(klass, "core dumps after login")
    Splam.configure { |c| c.profile = :lighthouse }
    klass = model { |s| s.rules = [:bad_words] }
    assert_equal 15, score(klass, "core dumps after login")
  end
end
