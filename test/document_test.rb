require File.expand_path('test_helper', File.dirname(__FILE__))

class DocumentTest < Test::Unit::TestCase
  def test_prepares_the_text_once
    doc = Splam::Document.new("Hi <a href=x>Viagra</a>")
    assert_equal "hi <a href=x>viagra</a>", doc.downcased
    assert_equal [["Viagra"]], doc.link_texts
    assert_equal [["viagra"]], doc.link_texts(true)
    assert_same doc.link_texts, doc.link_texts
    assert_equal [" href=x"], doc.link_attributes.flatten
  end

  def test_scrubs_invalid_utf8
    doc = Splam::Document.new("a \xFF b".force_encoding("UTF-8"))
    assert doc.text.valid_encoding?
    assert_equal "a  b", doc.text
  end

  SEEN = []
  class SeesDocumentA < Splam::Rule
    def run; SEEN << document; end
  end
  class SeesDocumentB < Splam::Rule
    def run; SEEN << document; end
  end
  Splam::Rule.default_rules.delete(SeesDocumentA)
  Splam::Rule.default_rules.delete(SeesDocumentB)

  def test_rules_share_the_suites_document
    SEEN.clear
    klass = Class.new { include ::Splam; attr_accessor :body; splammable(:body) { |s| s.rules = [SeesDocumentA, SeesDocumentB] } }
    doc = klass.new
    doc.body = "x"
    doc.splam_score
    assert_equal 2, SEEN.size
    assert_same SEEN[0], SEEN[1]
  end

  def test_rule_scores_per_field
    klass = Class.new { include ::Splam; attr_accessor :body; splammable(:body) { |s| s.rules = [:bbcode, :russian] } }
    doc = klass.new
    doc.body = "[url=x"
    assert_equal({ :body => { :bbcode => 40, :russian => 0 } }, doc.splam_rule_scores)
  end
end
