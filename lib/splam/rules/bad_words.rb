class Splam::Rules::BadWords < Splam::Rule
  
  def run
    bad_words = %w( sex sexy porn gay erotica viagra xxx erotismo porno porn)
    suspicious_words = %w( free buy galleries dating gallery hard hardcore video homemade celebrity adult pharmacy overnight shipping free)
    suspicious_words << "forums/member.php?u="
    bad_words.each do |word|
      add_score 10 * @body.scan(word).size, "nasty word: '#{word}'"
    end
    suspicious_words.each do |word|
      add_score 2 * @body.scan(word).size, "suspicious word: #{word}"
    end
  end
end