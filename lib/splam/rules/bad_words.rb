class Splam::Rules::BadWords < Splam::Rule
  
  def run
    bad_words = %w( sex sexy porn gay erotica viagra xxx erotismo porno porn lesbian amateur tit)
    bad_words |= %w( gratis erotismo porno torrent bittorrent adulto )
    bad_words << /pel?cula/ << /pornogr?fica/ # srsly, spamming in spanish?

    suspicious_words = %w( free buy galleries dating gallery hard hardcore video homemade celebrity adult pharmacy overnight shipping free hot movie nylon)
    suspicious_words << "forums/member.php?u=" << "chat room" << "free chat"
    bad_words.each do |word|
      results = @body.downcase.scan(word) 
      if results && results.size > 0
        add_score((10^results.size), "nasty word: '#{word}'")
        # Add more points if the bad word is INSIDE a link
        @body.scan(/<a[^>]+>(.*?)<\/a>/).each do |match|
          add_score 20 ^ match[0].scan(word).size, "nasty word inside a link: #{word}"
        end
      end
    end
    suspicious_words.each do |word|
      results = @body.downcase.scan(word) 
      if results && results.size > 0
        add_score (2 ^ results.size), "suspicious word: #{word}"
        # Add more points if the bad word is INSIDE a link
        @body.scan(/<a[^>]+>(.*?)<\/a>/).each do |match|
          add_score((4 ^ match[0].scan(word).size), "suspicious word inside a link: #{word}")
        end
      end
    end
  end
end