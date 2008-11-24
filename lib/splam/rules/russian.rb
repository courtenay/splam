class Splam::Rules::Russian < Splam::Rule

  def run
    banned_words =[ # various russian characters
      "\320\241", "\320\220", "\320\234", "\320\257", "\320\233", "\320\243", 
      "с", "м", "о", "т", "р", "е", "т", "ь", "п", "о", "р", "н", "о", "р", "л", "и", "к"
      # unicode char
#      "\320"
    ]
    banned_words.each do |word|
      hits = (3 * @body.scan("#{word}").size) # 1 point for every banned word
      add_score hits, "Suspicious character '#{word}'"
    end
  end
end