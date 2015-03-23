# encoding: UTF-8

class Splam::Rules::True < Splam::Rule

  # We get a number of spam comments that are just one word:
  # true, comment_body, "8趷", ...
  def run
    tokens = Splam::Ngram.tokenize @body.strip
    add_score 100, "Body is just one word" if tokens.size == 1
  end
  
end
