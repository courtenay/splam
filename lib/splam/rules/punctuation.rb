class Splam::Rules::Punctuation < Splam::Rule
  
  def run
    punctuation = @body.scan(/[.,] /)
    add_score 10, "Text has no punctuation" if punctuation.size == 0

    @body.split(/[.,]/).each do |sentence|
      words = sentence.split(" ")
      # long sentence, add a point.
      add_score 1, "Sentence has more than 10 words" if words.size > 10
      add_score 10, "Sentence has more than 30 words" if words.size > 30
    end
  end
end