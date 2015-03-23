class Splam::Rules::Korean < Splam::Rule

  def run
    banned_words = [
      "밤", "의", "전", "쟁"
    ]
    banned_words.each do |word|
      hits = (3 * @body.scan("#{word}").size) # 1 point for every banned word
      add_score hits, "Suspicious korean character '#{word}'"
    end
  end
end