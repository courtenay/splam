class Splam::Rules::Chinese < Splam::Rule

  def run
    banned_words =[ # various chinese characters
      "\350\263\207",
      "\351\207\221",
      # "\357", # ugh, these don't work .. because they're only part of a character.
      # "\351",
      "\35"
    ]
    banned_words.each do |word|
      hits = (3 * @body.scan(word).size) # 1 point for every banned word
      add_score hits, "Banned character: #{word}"
    end
  end
end