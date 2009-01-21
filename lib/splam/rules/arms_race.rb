class Splam::Rules::ArmsRace < Splam::Rule
  class << self
    attr_accessor :bad_word_score
  end

  self.bad_word_score = 40

  # This is where you put banned domain names or otherwise
  def run
    shitty_sites = ["inquisitr"]    
    shitty_sites.each do |word|
      results = @body.downcase.scan(word) 
      if results && results.size > 0
        add_score((self.class.bad_word_score ** results.size), "stupid site: '#{word}'")
        @body.scan(/<a[^>]+>(.*?)<\/a>/).each do |match|
          add_score self.class.bad_word_score * 4 * match[0].scan(word).size, "nasty word inside a link: #{word}"
        end
        @body.scan(/<a(.*?)>/).each do |match|
          add_score self.class.bad_word_score * 4 * match[0].scan(word).size, "nasty word inside a URL: #{word}"
        end
      end
    end
  end
end