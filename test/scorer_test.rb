# encoding: UTF-8
require File.expand_path('test_helper', File.dirname(__FILE__))
require 'tempfile'

class ScorerTest < Test::Unit::TestCase
  def teardown
    Splam.reset_config!
  end

  class Post
    include ::Splam
    attr_accessor :body, :site_id
    splammable(:body, 250) { |s| s.rules = [:bad_words, :bbcode] }
  end

  def post(body)
    p = Post.new
    p.body = body
    p
  end

  def test_result_has_rule_features_and_no_probability_without_a_scorer
    r = post("[url=x] viagra").splam_result
    assert_equal r.score, post("[url=x] viagra").splam_score
    assert_equal 40, r.features["body.rule.bbcode"]
    assert_operator r.features["body.rule.bad_words"], :>, 0
    assert_nil r.probability
  end

  def test_app_features_and_text_model_log_odds
    model = Splam::TextModel.new(Splam::TextModel::MemoryStore.new)
    model.train(1, "cheap pills online", :spam)
    model.train(2, "my login is broken", :ham)
    Splam.configure do |c|
      c.extra_features = lambda { |record| { "via_email" => 1 } }
      c.text_model = lambda { |record| model }
    end
    f = post("cheap pills").splam_result.features
    assert_equal 1, f["via_email"]
    assert_operator f["text.log_odds"], :>, 0
  end

  def test_linear_scorer
    scorer = Splam::LinearScorer.from_hash(
      "bias" => -1.0,
      "features" => {
        "body.rule.bbcode" => { "weight" => 0.5, "transform" => "slog" },
        "text.log_odds" => { "weight" => 0.1, "transform" => "clip", "min" => -10, "max" => 10 },
        "via_email" => { "weight" => 2.0, "transform" => "raw" },
      })
    values = { "body.rule.bbcode" => 40, "text.log_odds" => 300, "via_email" => 1 }
    expected = -1.0 + 0.5 * Math.log(41) + 0.1 * 10 + 2.0
    assert_in_delta expected, scorer.logit(values), 1e-9
    assert_in_delta 1 / (1 + Math.exp(-expected)), scorer.probability(values), 1e-9
    assert_equal "via_email", scorer.contributions(values).first.first
    assert_in_delta(-1.0, scorer.logit({}), 1e-9) # missing features count as 0
    assert_in_delta(-Math.log(6), Splam::LinearScorer.transform({ "transform" => "slog" }, -5), 1e-9)
  end

  def test_scorer_loads_from_json_and_gives_results_a_probability
    f = Tempfile.new(['weights', '.json'])
    f.write('{"bias": -3.0, "features": {"body.rule.bbcode": {"weight": 1.0, "transform": "slog"}}}')
    f.close
    Splam.configure { |c| c.scorer = Splam::LinearScorer.load(f.path) }
    r = post("[url=x]").splam_result
    assert_in_delta Splam::TextModel.probability(-3.0 + Math.log(41)), r.probability, 1e-9
    assert_equal "body.rule.bbcode", r.top_features.first.first
  end

  def test_check_without_a_model_class
    r = Splam.check("[url=x] cheap", :rules => [:bbcode], :features => { "first_comment" => 1 })
    assert_equal 40, r.score
    assert_equal 40, r.features["body.rule.bbcode"]
    assert_equal 1, r.features["first_comment"]
  end

  def test_check_runs_the_default_rules
    assert_equal post("[url=x] viagra").splam_score - 0, Splam.check("[url=x] viagra", :rules => [:bad_words, :bbcode]).score
    assert_kind_of Numeric, Splam.check("hello there").score
  end
end

class CopycatTest < Test::Unit::TestCase
  SOURCE = "I had the same problem with exporting reports, restarting the app fixed it."

  def teardown
    Splam.reset_config!
  end

  def copy_features(text, matches)
    Splam.configure { |c| c.similar_texts = lambda { |record, t| matches } }
    Splam.check(text, :rules => [:copycat]).features.select { |k, _| k.include?("copy.") }
  end

  def test_nothing_without_a_lookup
    assert_equal({}, Splam.check("anything", :rules => [:copycat]).features.select { |k, _| k.include?("copy.") })
  end

  def test_a_reworded_copy_with_a_new_trailing_link
    f = copy_features("I had the same issue exporting reports, restarting the app fixed it. http://cheap.example/x",
                      [{ :text => SOURCE }])
    assert_operator f["body.copy.similarity"], :>, 0.7
    assert_equal 1, f["body.copy.added_links"]
    assert_equal 1, f["body.copy.trailing_link"]
  end

  def test_uses_the_lookups_similarity_and_skips_the_same_author
    f = copy_features("whatever http://a.example", [{ :text => "x", :similarity => 0.95, :same_author => true },
                                                    { :text => "y http://a.example", :similarity => 0.4 }])
    assert_equal 0.4, f["body.copy.similarity"]
    assert_equal 0, f["body.copy.added_links"] # the source had that link
    assert_equal 0, f["body.copy.trailing_link"]
  end

  def test_a_failing_lookup_adds_nothing
    Splam.configure { |c| c.similar_texts = lambda { |record, t| raise "search is down" } }
    assert_equal 0, Splam.check("x", :rules => [:copycat]).score
  end

  def test_overlap
    assert_equal 1.0, Splam::Rules::Copycat.overlap("The cat sat", "the CAT sat http://x.example")
    assert_equal 0.0, Splam::Rules::Copycat.overlap("dogs only", "cats here")
  end
end
