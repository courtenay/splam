class Splam::Rules::BadWords < Splam::Rule
  class << self
    attr_accessor :bad_word_score, :suspicious_word_score
  end
  
  self.bad_word_score       = 10
  self.suspicious_word_score = 4

  def run
    bad_words = %w( sex sexy porn gay erotica viagra erotismo porno porn lesbian amateur tit)
    bad_words |= %w( gratis erotismo porno torrent bittorrent adulto )
    bad_words |= %w( cialis viagra payday loan jihad )
    bad_words |= %w( webcam  free-web-host rapidshare muslim)
    bad_words << /pel?cula/ << /pornogr?fica/ << "portal porno" # srsly, spamming in spanish?

    suspicious_words =  %w( free buy galleries dating gallery hard hardcore video homemade celebrity ) << "credit card" << "my friend" << "friend sent me"
    suspicious_words |= %w( adult pharmacy overnight shipping free hot movie nylon arab ?????? xxx) << "sent me a link"
    suspicious_words << "forums/member.php?u=" << "chat room" << "free chat" << "yahoo chat" << "page.php"
    bad_words.each do |word|
      results = @body.downcase.scan(word) 
      if results && results.size > 0
        add_score((self.class.bad_word_score ** results.size), "nasty word: '#{word}'")
        # Add more points if the bad word is INSIDE a link
        @body.scan(/<a[^>]+>(.*?)<\/a>/).each do |match|
          add_score self.class.bad_word_score * 4 * match[0].scan(word).size, "nasty word inside a link: #{word}"
        end
        @body.scan(/\nhttp:\/\/(.*?#{word})/).each do |match|
          add_score self.class.bad_word_score ** 4 * match[0].scan(word).size, "nasty word inside a straight-up link: #{word}"
        end
        @body.scan(/<a(.*?)>/).each do |match|
          add_score self.class.bad_word_score * 4 * match[0].scan(word).size, "nasty word inside a URL: #{word}"
        end
      end
    end
    suspicious_words.each do |word|
      results = @body.downcase.scan(word) 
      if results && results.size > 0
        add_score (self.class.suspicious_word_score * results.size), "suspicious word: #{word}"
        # Add more points if the bad word is INSIDE a link
        @body.scan(/<a[^>]+>(.*?)<\/a>/).each do |match|
          add_score((self.class.suspicious_word_score * match[0].scan(word).size), "suspicious word inside a link: #{word}")
        end
      end
    end
  end
end