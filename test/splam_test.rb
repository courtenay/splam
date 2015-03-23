require File.join(File.dirname(__FILE__), 'test_helper')
require 'activesupport'

class SplamTest < Test::Unit::TestCase
  class FixedRule < Splam::Rule
    def run
      add_score 25, "The force is strong with this one"
    end
  end

  # It should not be in the default set
  Splam::Rule.default_rules.delete SplamTest::FixedRule

  class Foo
    include ::Splam
    splammable :body
    attr_accessor :body
    def body
      @body || "This is body\320\224 \320\199"
    end
  end

  class FooReq
    include ::Splam
    splammable :body do |s|
      s.rules = [ Splam::Rules::Keyhits, Splam::Rules::True ]
    end
    attr_accessor :body
    attr_accessor :request
    def request(obj)
      @request
    end
  end

  class FooCond
    include ::Splam
    splammable :body, 0, lambda { |s| false }
    attr_accessor :body
  end

  class PickyFoo
    include ::Splam
    splammable :body do |s|
      s.rules = [:fixed_rule, FixedRule]
    end

    def body
      'lol wut'
    end
  end

  class HeavyFoo
    include ::Splam
    splammable :body do |s|
      s.rules = {:fixed_rule => 3}
    end

    def body
      'lol wut'
    end
  end

  def test_runs_plugins
    f = Foo.new
    assert ! f.splam?
    assert_equal 10, f.splam_score
  end

  def test_runs_plugins_with_specified_rules
    f = PickyFoo.new
    assert ! f.splam?
    assert_equal 25, f.splam_score
  end

  def test_runs_plugins_with_specified_weighted_rules
    f = HeavyFoo.new
    assert ! f.splam?
    assert_equal 75, f.splam_score
  end

  def test_runs_conditions
    f = FooCond.new
    assert f.splam? # it IS spam, coz threshold is 0
  end

  def test_scores_spam_really_high
    Dir.glob(File.join(File.dirname(__FILE__), "fixtures", "comment", "spam", "*.txt")).each do |f|
      comment = Foo.new
      spam = File.open(f).read
      comment.body = spam
      # some spam have a lower threshold denoted by their filename
      # trickier to detect
      if f =~ /\/(\d+)_.*\.txt/
        Foo.splam_suite.threshold = $1.to_i
      else
        Foo.splam_suite.threshold = 180
      end
      spam  = comment.splam?
      score = comment.splam_score
      #$stderr.puts "#{f} score: #{score}\n#{comment.splam_reasons.inspect}"
      #$stderr.puts "====================="
      assert spam, "Comment #{f} was not spam, score was #{score} but threshold was #{Foo.splam_suite.threshold}\nReasons were #{comment.splam_reasons.inspect}"
    end
  end
  
  def test_scores_ham_low
    Dir.glob(File.join(File.dirname(__FILE__), "fixtures", "comment", "ham", "*.txt")).each do |f|
      comment = Foo.new
      comment.body = File.open(f).read
      spam = comment.splam?
      score = comment.splam_score
      #$stderr.puts "#{f} score: #{score}"
      #$stderr.puts "====================="
      
      assert !spam, "File #{f} should be marked ham < #{Foo.splam_suite.threshold}, but was marked with score #{score}\nReasons were #{comment.splam_reasons.inspect}\n\n#{comment.body}"
    end
  end

  def test_keyhits_with_true
    f = FooReq.new
    f.body = "true"
    f.request = {:counter => "", :time => 3, :remote_ip => "1.2.3.4"}
    assert f.splam?
    assert_equal 300, f.splam_score
  end

  def test_keyhits_with_word
    f = FooReq.new
    f.body = "8趷"
    f.request = {:counter => "", :time => 3, :remote_ip => "1.2.3.4"}
    assert f.splam?
    assert_equal 300, f.splam_score
  end
end
