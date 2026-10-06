# encoding: utf-8
class Splam::Rules::Korean < Splam::Rule
  # Off by default since 0.4 (Korean text was nearly all ham in Tender's
  # labelled comments); a suite can still name it.
  def self.opt_in?
    true
  end

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