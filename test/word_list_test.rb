require File.expand_path('test_helper', File.dirname(__FILE__))
require 'tempfile'

class WordListTest < Test::Unit::TestCase
  def test_parses_entries
    f = Tempfile.new(['words', '.txt'])
    f.write("# a comment\n\nviagra\n  dear,  \nre:/pel?cula/\nre:/Support Number/i\n")
    f.close
    assert_equal ["viagra", "dear,", /pel?cula/, /Support Number/i], Splam::WordList.read(f.path)
  end

  def test_bad_word_lists_by_profile
    default, suspicious = Splam::Rules::BadWords.lists(false)
    lighthouse, = Splam::Rules::BadWords.lists(true)
    assert_include default[:viagraspam], "viagra"
    assert_not_include default[:pornspam], "video"
    assert_include lighthouse[:pornspam], "video"
    assert_nil default[:dumps]
    assert_equal %w(dumps okta), lighthouse[:dumps]
    assert_include suspicious, "free chat"
    assert default.values.flatten.any? { |e| e.equal?(Splam::Rules::BadWords::LOVE_SOLUTION) }
  end

  def test_every_regex_compiles_and_every_entry_is_clean
    Dir[File.join(Splam::WordList::DIR, "**", "*.txt")].each do |path|
      Splam::WordList.read(path).each do |e|
        next if e.is_a?(Regexp)
        assert_equal e.strip, e, path
        assert_kind_of Regexp, Splam::Rules::BadWords.word_regex(e) if path.include?("bad_words")
      end
    end
  end
end
