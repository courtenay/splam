class Splam::Rules::Chinese < Splam::Rule
  class << self
    attr_accessor :base_score
  end
  self.base_score = 3

  def run
    banned_words =[ # various chinese characters
      "\350\263\207",
      "\351\207\221",
      "\357\274\222", # number 2 in weird unicode
      "\357\274\224", # number 4 
      "\357\274\225", # number 5
      "\357\274\231", # number 9
      
      "\345\260\232",
      "\345\256\266",
      "\345\274\267",
      "\345\240\261",
      "\345\260\216",
      "\345\217\260",
      "\345\215\227",
      "\346\235\261",
      "\345\270\202",
      "\345\240\264",
      "\345\202\263",
      "\346\216\250",
      "\346\231\202",
      "\347\203\210",
      "\347\216\251",
      "\350\226\246",
      "\350\217\234",
      "\350\216\216",
      
      "\357\274\215", # hyphen
      /\\357\2\d\d\\\d{3}/,
      # "\357", # ugh, these don't work .. because they're only part of a character.
      # "\351",
      "\35"
    ]
    banned_words.each do |word|
      hits = (self.class.base_score * @body.scan(word).size) # 1 point for every banned word
      add_score hits, "Banned character: #{word}"
    end
  end
end