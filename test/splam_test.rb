require File.expand_path('test_helper', File.dirname(__FILE__))

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

  # Apps add their own rules by subclassing Splam::Rule; this one reads the
  # request the model passes in.
  class FormTimer < Splam::Rule
    def run
      return unless @request && @request[:time]
      add_score 300, "Submitted within 2 seconds" if @request[:time] < 2
    end
  end
  Splam::Rule.default_rules.delete FormTimer

  class FooReq
    include ::Splam
    splammable :body do |s|
      s.rules = [ FormTimer, Splam::Rules::True ]
      s.request = lambda { |r| r.request }
    end
    attr_accessor :body, :request
  end

  class TwoFields
    include ::Splam
    attr_accessor :body, :title
    splammable :body, 100 do |s|
      s.rules = [FixedRule]
    end
    splammable :title, 20, lambda { |r| !r.title.nil? } do |s|
      s.rules = { FixedRule => 2 }
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
    assert_nil f.splam_scores[:body] # the condition is false, so the suite didn't run
    assert !f.splam?
    always = Class.new { include ::Splam; splammable :body, 0, lambda { |r| true }; attr_accessor :body }.new
    always.body = "hello there"
    assert always.splam? # threshold 0
  end

  # Which fixtures each profile gets wrong today (spam under its threshold,
  # 180 or the number in its file name; ham at 100 or more). Golden lists, so
  # that a scoring change shows up here; fixes in 0.5 shorten them.
  KNOWN_WRONG = {
    :default    => { :spam => %w(amazon.txt comment_bbc.txt ottersex.txt spam-13518.txt spam-13519.txt spam-13520.txt spam-13521.txt),
                     :ham  => [] },
    :lighthouse => { :spam => %w(comment_bbc.txt ottersex.txt),
                     :ham  => %w(feedlinks.txt mario.txt mylyn.txt sample_html.txt) },
  }

  def fixtures_wrong(profile)
    Splam.configure { |c| c.profile = profile }
    klass = Class.new { include ::Splam; splammable :body; attr_accessor :body }
    wrong = { :spam => [], :ham => [] }
    dir = File.join(File.dirname(__FILE__), "fixtures", "comment")
    Dir.glob(File.join(dir, "spam", "*.txt")).sort.each do |f|
      threshold = f =~ /\/(\d+)_.*\.txt/ ? $1.to_i : 180
      doc = klass.new
      doc.body = File.read(f, :encoding => "UTF-8")
      wrong[:spam] << File.basename(f) if doc.splam_score < threshold
    end
    Dir.glob(File.join(dir, "ham", "*.txt")).sort.each do |f|
      doc = klass.new
      doc.body = File.read(f, :encoding => "UTF-8")
      wrong[:ham] << File.basename(f) if doc.splam_score >= 100
    end
    wrong
  ensure
    Splam.reset_config!
  end

  def test_fixtures_default_profile
    assert_equal KNOWN_WRONG[:default], fixtures_wrong(:default)
  end

  def test_fixtures_lighthouse_profile
    assert_equal KNOWN_WRONG[:lighthouse], fixtures_wrong(:lighthouse)
  end

  def test_app_rule_with_request
    f = FooReq.new
    f.body = "true"
    f.request = { :time => 1 }
    assert f.splam?
    assert_equal 300 + 100, f.splam_score # FormTimer, then True's one-word body
  end

  def test_scores_per_field
    f = TwoFields.new
    f.body, f.title = "b", "t"
    assert_equal 25 + 50, f.splam_score
    assert_equal({ :body => 25, :title => 50 }, f.splam_scores)
    assert !f.splam?(:body)
    assert f.splam?(:title)
    assert f.splam?
    assert_equal [:body, :title], f.splam_reasons_by_field.keys
    assert_kind_of Array, f.splam_reasons # flat, one array per rule
  end

  def test_skipped_suite_is_not_spam
    f = TwoFields.new
    f.body = "b"
    assert !f.splam?(:title)
    assert !f.splam?
  end
end
