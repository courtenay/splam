require File.expand_path('test_helper', File.dirname(__FILE__))
require 'timeout'

# Splam runs inside requests and jobs, so no rule may take super-linear time on
# a hostile body, and the linear scans must find what the old regexes found.
class LinearScanTest < Test::Unit::TestCase
  class Doc
    include ::Splam
    attr_accessor :body
  end

  def teardown
    Splam.reset_config!
  end

  def score(body, profile = :default)
    Splam.configure { |c| c.profile = profile }
    klass = Class.new(Doc) { splammable :body }
    doc = klass.new
    doc.body = body
    doc.splam_score
  end

  HOSTILE = {
    "bad words and unclosed <a"         => "viagra cialis porn " + "<a" * 20_000,
    "bad words and <a> tags"            => "viagra cialis " + "<a x>" * 10_000,
    "bad words and http:// run"         => "viagra " + "http://" * 10_000,
    "'love' repeated on one line"       => "love " * 20_000,
    "'love' after a love-solution link" => "love solution http://" + "love " * 20_000,
    "'love' in a tag after a pair"      => "love solution <a " + "love " * 20_000 + ">",
    "a run of <"                        => "<" * 50_000 + ">x",
    "<a on the last line"               => "<a" * 30_000 + "</a>",
  }

  HOSTILE.each_with_index do |(label, body), i|
    [:default, :lighthouse].each do |profile|
      define_method("test_hostile_#{i}_#{profile}") do
        assert_nothing_raised("#{label} (#{profile}) took too long") { Timeout.timeout(5) { score(body, profile) } }
      end
    end
  end

  def test_scores_as_the_old_regexes_did
    body = %(cheap <a href="http://x.com/pills">buy <b>viagra</b></a> at http://spam.example/ now viagra\n) +
           %(<a title="casino"><b>win</b></a> love the solution)
    assert_equal 160_384, score(body) # Tender's pinned score
  end

  def test_invalid_utf8
    assert_kind_of Numeric, score("viagra \xFF\xFE <a href=x>y</a>".force_encoding('UTF-8'))
  end

  def random_text(pieces, n)
    Array.new(rand(n)) { pieces.sample }.join
  end

  def test_link_scans_match_the_regexes
    srand 5
    pieces = ["<a", ">", "</a>", "x", " ", "\n", "<b>", "http://", "viagra"]
    3000.times do
      t = random_text(pieces, 12)
      assert_equal t.scan(/<a[^>]+>(.*?)<\/a>/), Splam::LinearScan.link_texts(t), t.inspect
      assert_equal t.scan(/<a(.*?)>/), Splam::LinearScan.link_attributes(t), t.inspect
      assert_equal t.scan(/<a[^>]*><b>/).size, Splam::LinearScan.bold_link_count(t), t.inspect
      assert_equal t.scan(/\bhttp:\/\/(.*?viagra)/), Splam::LinearScan.http_links_to(t, 'viagra'), t.inspect
    end
  end

  def test_trailing_checks_match_the_regexes
    srand 7
    html = Splam::Rules::Html.allocate
    href = Splam::Rules::Href.allocate
    pieces = ["<a", "</a>", "a", "\n", " ", "<", "/a>", ">", "!"]
    5000.times do
      t = random_text(pieces, 10)
      s = t.strip
      assert_equal !!(s =~ /[<][^>]*[>]\Z/), html.send(:ends_in_tag?, s), s.inspect
      href.instance_variable_set(:@body, t)
      assert_equal t.scan(/<a.*?<\/a>\Z/).size, href.send(:trailing_link_post), t.inspect
    end
  end
end
