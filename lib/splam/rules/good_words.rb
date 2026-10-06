class Splam::Rules::GoodWords < Splam::Rule

  # data/good_words.txt, compiled once: a Regexp as given; a word or phrase
  # must match whole (before 0.5 this scanned the string "\b#{word}\b", whose
  # \b are backspaces, so it never matched)
  def self.patterns
    @patterns ||= Splam::WordList.read("good_words.txt").map do |word|
      [word, word.is_a?(Regexp) ? word : /(?<![[:word:]])#{Regexp.escape(word)}(?![[:word:]])/]
    end
  end

  def run
    body = @document.downcased
    self.class.patterns.each do |word, pattern|
      add_score -5 * body.scan(pattern).size, "relevant word match: #{word}"
    end
  end
end
