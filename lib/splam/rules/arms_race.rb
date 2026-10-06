class Splam::Rules::ArmsRace < Splam::Rule
  class << self
    attr_accessor :bad_word_score
  end

  self.bad_word_score = 40

  # This is where you put banned domain names or otherwise
  def run

    shitty_sites = ["inquisitr", "beeplog"]
    shitty_sites.each do |word|
      results = @document.downcased.scan(word)
      if results && results.size > 0
        add_score((self.class.bad_word_score ** results.size), "stupid site: '#{word}'")
        # the /<a[^>]+>(.*?)<\/a>/ and /<a(.*?)>/ scans, in linear time
        @document.link_texts.each do |match|
          add_score self.class.bad_word_score * 4 * match[0].scan(word).size, "nasty word inside a link: #{word}"
        end
        @document.link_attributes.each do |match|
          add_score self.class.bad_word_score * 4 * match[0].scan(word).size, "nasty word inside a URL: #{word}"
        end
      end
    end
  end
end