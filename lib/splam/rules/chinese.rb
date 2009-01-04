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