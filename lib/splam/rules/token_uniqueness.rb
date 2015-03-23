class Splam::Rules::TokenUniqueness < Splam::Rule

  def run
    words = Splam::Ngram.tokenize @body
    return if words.size < 30 || words.size > 10000

    tokens = Splam::Ngram.trigram @body
    
    # only a few words repeated, lots ofo words
    add_score 300, "Small vocabulary" if tokens.keys.size < 10 && words.size > 50
  end
end