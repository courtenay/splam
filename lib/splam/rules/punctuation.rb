class Splam::Rules::Punctuation < Splam::Rule
  
  def run
    score = 0
    
    @body.split(".").each do |sentence|
      words = sentence.split(" ")
      # long sentence, add a point.
      score += 1 if words.size > 10
      
      # 30 words in a sentence? spam
      score += 10 if words.size > 30
    end
    score
  end
end