class Splam::Rules::BadWords < Splam::Rule
  
  def run
    bad_words = %w( sex sexy porn gay )
    suspicious_words = %w( free buy galleries gallery hard pharmacy overnight shipping)
    bad_words.each do |word|
      add_score 5 * @body.scan(word).size, "nasty word: '#{word}'"
    end
    suspicious_words.each do |word|
      add_score 2 * @body.scan(word).size, "suspicious word: #{word}"
    end
  end
end