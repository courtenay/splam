require 'test/unit'
$:.unshift(File.dirname(__FILE__) + '/../lib')
$:.unshift(File.dirname(__FILE__) + '/../lib/splam')

require 'splam'
require 'splam/rule'
require 'splam/rules'
# require 'splam/rules/russian'

class Foo
  include ::Splam
  attr_accessor :body
  def body
    @body || "This is body\320\224 \320\199"
  end
end


class SplamTest < Test::Unit::TestCase
  
  def test_runs_plugins
    f = Foo.new
    assert_equal 6, f.splammable(:body)
  end

  def test_scores_spam_really_high
    comment = Foo.new
    Dir.glob(File.join(File.dirname(__FILE__), "fixtures", "comment", "spam", "*.txt")).each do |f|
      spam = File.open(f).read
      comment.body = spam
      score = comment.splammable(:body)
      $stderr.puts "#{f} score: #{score}"
      if f =~ /\/(\d+)_\w+\.txt/
        $stderr.puts $1.to_i
        assert (score >= $1.to_i)
      else
        assert (score >= 100)
      end
    end
  end
  
  def test_scores_ham_low
    comment = Foo.new
    Dir.glob(File.join(File.dirname(__FILE__), "fixtures", "comment", "ham", "*.txt")).each do |f|
      spam = File.open(f).read
      comment.body = spam
      score = comment.splammable(:body)
      $stderr.puts "#{f} score: #{score}"
      if f =~ /\/(\d+)_\w+\.txt/
        $stderr.puts $1.to_i
        assert (score >= $1.to_i)
      else
        assert (score < 50)
      end
    end
  end
  
end
