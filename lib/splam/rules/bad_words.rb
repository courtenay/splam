class Splam::Rules::BadWords < Splam::Rule
  
  def run
    score = 0
    bad_words = %w( sex sexy porn gay )
    suspicious_words = %w( free buy galleries gallery hard pharmacy overnight shipping)
    bad_words.each do |word|
      score += 5 * @body.scan(word).size
    end
    suspicious_words.each do |word|
      score += 2 * @body.scan(word).size
    end    
    score
  end
end