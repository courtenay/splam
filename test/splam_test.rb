require File.join(File.dirname(__FILE__), 'test_helper')

class Foo
  include ::Splam
  splammable :body
  attr_accessor :body
  def body
    @body || "This is body\320\224 \320\199"
  end
end

class FooCond
  include ::Splam
  splammable :body, 0, lambda { |s| false }
  attr_accessor :body
end

class SplamTest < Test::Unit::TestCase
  
  def test_runs_plugins
    f = Foo.new
    assert ! f.splam?
    assert_equal 10, f.splam_score
  end
  
  def test_runs_conditions
    f = FooCond.new
    assert ! f.splam?
  end

  def test_scores_spam_really_high
    comment = Foo.new
    Dir.glob(File.join(File.dirname(__FILE__), "fixtures", "comment", "spam", "*.txt")).each do |f|
      spam = File.open(f).read
      comment.body = spam
      # some spam have a lower threshold denoted by their filename
      # trickier to detect
      if f =~ /\/(\d+)_\w+\.txt/
        Foo.splam[:threshold] = $1.to_i
      else
        Foo.splam[:threshold] = 99
      end
      spam = comment.splam?
      score = comment.splam_score
      #$stderr.puts "#{f} score: #{score}"
      #$stderr.puts "====================="
      assert spam, "Comment #{f} was not spam, score was #{score} but threshold was #{Foo.splam[:threshold]}\nReasons were #{comment.splam_reasons.inspect}"
    end
  end
  
  def test_scores_ham_low
    comment = Foo.new
    Dir.glob(File.join(File.dirname(__FILE__), "fixtures", "comment", "ham", "*.txt")).each do |f|
      comment.body = File.open(f).read
      spam = comment.splam?
      score = comment.splam_score
      #$stderr.puts "#{f} score: #{score}"
      #$stderr.puts "====================="
      
      assert !spam, "File #{f} should be marked ham, but was marked with score #{score}\nReasons were #{comment.splam_reasons}\n\n#{comment.body}"
    end
  end
end
