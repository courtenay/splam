require File.expand_path('test_helper', File.dirname(__FILE__))

# One test per rule fix in 0.4, each scoring a body with one rule.
class RuleFixesTest < Test::Unit::TestCase
  def teardown
    Splam.reset_config!
  end

  def score(rule, body, profile = :default)
    Splam.configure { |c| c.profile = profile }
    klass = Class.new { include ::Splam; attr_accessor :body }
    klass.splammable(:body, 100) { |s| s.rules = [rule] }
    doc = klass.new
    doc.body = body
    doc.splam_score
  end

  def test_good_words_match_whole_words
    assert_equal(-10, score(:good_words, "my api request"))
    assert_equal 0, score(:good_words, "my apiary requests")  # not inside other words
    assert_equal(-5, score(:good_words, "see /usr/local/lib")) # starts with punctuation
  end

  def test_bad_word_link_bonus_needs_the_word_in_the_link
    plain = score(:bad_words, "viagra")
    with_other_links = score(:bad_words, "viagra <a href=x>one</a> <a href=y>two</a>")
    in_a_link = score(:bad_words, "<a href=x>viagra</a>")
    assert_equal plain, with_other_links
    assert in_a_link > plain
  end

  def test_one_genre_bonus_once
    # cashspam is payday, loan, jihad, "payday loan", /jihad/: 3 of them pass half
    body = "payday loan jihad"
    reasons = Class.new { include ::Splam; attr_accessor :body; splammable(:body) { |s| s.rules = [:bad_words] } }.new
    reasons.body = body
    genre = reasons.splam_reasons.flatten.grep(/Lots of bad words from one genre \(cashspam\)/)
    assert_equal 1, genre.size
  end

  def test_word_list_entries_starting_or_ending_in_punctuation_match
    w = Splam::Rules::BadWords
    assert_match w.word_regex("dear,"), "hi dear, how are you"
    assert_match w.word_regex(".xyz"), "go to foo.xyz now"
    assert_no_match w.word_regex("viagra"), "viagras"
  end

  def test_russian_letters_count_once
    assert_equal 3, score(:russian, "о")
  end

  def test_repeated_letter_means_a_letter_repeated
    # True looks at one-word bodies (+100 for that alone)
    assert_equal 100, score(:true, "hello")       # an ordinary word
    assert_equal 150, score(:true, "helloooooo")  # a run of o
  end

  def test_empty_body_is_not_just_links
    assert_equal 0, score(:href, "   ")
  end

  def reasons(rule, body)
    klass = Class.new { include ::Splam; attr_accessor :body }
    klass.splammable(:body, 100) { |s| s.rules = [rule] }
    doc = klass.new
    doc.body = body
    doc.splam_reasons.flatten
  end

  def test_bbcode_counts_img_tags_once_each
    assert_equal 1, reasons(:bbcode, "[IMG]x[/IMG]").grep(/IMG/).size
    assert_equal 1, reasons(:bbcode, "[img]x[/img]").grep(/IMG/).size
  end

  def test_word_length_leaves_links_out
    words = "one two six ten red map "
    assert_equal 0, score(:word_length, words + "https://example.com/" + "a" * 80)
  end

  def test_korean_text_scores_nothing_by_default
    klass = Class.new { include ::Splam; attr_accessor :body; splammable :body }
    doc = klass.new
    doc.body = "안녕하세요 로그인이 안 됩니다 의 전 밤"
    assert_equal [], doc.splam_reasons.flatten.grep(/korean|Hangul/i)
    doc = klass.new
    doc.body = "你好，我无法登录"
    assert doc.splam_reasons.flatten.grep(/CJK Unified/).any?
  end

  # :lighthouse profile rules
  User = Struct.new(:name, :email, :trusted) do
    def trusted?; trusted; end
  end

  def test_user_badlist_only_for_bad_addresses
    Splam.configure { |c| c.profile = :lighthouse }
    klass = Class.new { include ::Splam; attr_accessor :body, :user; splammable(:body) { |s| s.rules = [:user] } }
    ok = klass.new
    ok.body, ok.user = "hi", User.new("Ann", "ann@example.com", true)
    assert_equal 0, ok.splam_score
    bad = klass.new
    bad.body, bad.user = "hi", User.new("Bob", "bob@qq.com", true)
    assert_equal 50, bad.splam_score
  end

  def test_trailing_tag_excitement_needs_a_bang
    calm = score(:html, "thanks <b>x</b>", :lighthouse)
    excited = score(:html, "thanks! <b>x</b>", :lighthouse)
    assert_equal 20, excited - calm
  end

  def test_fuzz_runs
    assert score(:fuzz, "1a 2b 3c", :lighthouse) > 0
    assert_equal 0, score(:fuzz, "1a 2b in /Library/ backtrace", :lighthouse)
  end
end
