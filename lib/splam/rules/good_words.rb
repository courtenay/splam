class Splam::Rules::GoodWords < Splam::Rule
  
  def run
    good_words = [ /I\'having a problem/, ]
    good_words |= %w( lighthouse install eclipse settings assigned user ticket tickets token api number query request)
    good_words |= %w( project billing tags description comment)
    good_words.each { |rule| 
      add_score -5 * @body.scan(rule).size, "relevant word match: #{rule}"
    }
  end
end