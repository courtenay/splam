class Splam::Rules::Fuzz < Splam::Rule
  # opt-in: part of the :lighthouse profile
  def self.opt_in?
    true
  end

  class << self
    attr_accessor :bad_word_score
  end
  
  self.bad_word_score = 10

  def run
    patterns = [/^(\d[a-z])/, /(\d[a-z][A-Z]\w+)/, /(\b\w+\d\.txt)/, /(;\d+;)/ ]
    ignore_if = [%r{vendor/rails}, /EXC_BAD_ACCESS/, /JavaAppLauncher/, %r{Contents/MacOS}, %r{/Library/}]
    matches = 0
    # looks like a stack trace
    # (before 0.5 `return if @body.scan(pattern)` always returned: [] is truthy)
    return if ignore_if.any? { |pattern| @body =~ pattern }
    patterns.each do |pattern|
      results = @body.scan(pattern)
      if results && results.size > 0
        add_score((self.class.bad_word_score * results.size), "bad pattern match: '#{$1}'")
      end
      matches += results.size
    end
    add_score matches ** 4, "Aggregate number of bad patterns was #{matches}." if matches > 1
  end
end