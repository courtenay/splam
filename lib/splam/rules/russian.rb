class Splam::Rules::Russian < Splam::Rule

  def run
    score = 0
    banned_words =[ # various russian characters
      "\320\241", "\320\220", "\320\234", "\320\257", "\320\233", "\320\243", 
      "с", "м", "о", "т", "р", "е", "т", "ь", "п", "о", "р", "н", "о", "р", "л", "и", "к",
      # unicode char
      "\320"
    ]
    banned_words.each do |word|
      score += (3 * @body.scan("#{word}").size) # 1 point for every banned word
    end
    score
  end
end