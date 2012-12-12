require 'active_support'
class Splam::Rules::BadWords < Splam::Rule
  class << self
    attr_accessor :bad_word_score, :suspicious_word_score
  end
  
  self.bad_word_score       = 10
  self.suspicious_word_score = 4

  def run
    bad_words = {}
    bad_words[:pornspam] = %w( sex sexy porn gay erotica erotico topless naked viagra erotismo porno porn lesbian amateur tit\b)
    bad_words[:pornspam] |= %w( gratis erotismo porno torrent bittorrent adulto videochat  video 3dsex)
    bad_words[:pornspam] << /pel?cula/ << /pornogr?fica/ << "portal porno" # srsly, spamming in spanish?
    bad_words[:pornspam] |= %w( webcam  free-web-host rapidshare)

    bad_words[:viagraspam] = %w( cialis viagra pharmacy prescription levitra kamagra)
    bad_words[:benzospam]  = %w( ultram tramadol pharmacy prescription )
    bad_words[:cashspam]   = %w( payday loan jihad ) << "payday loan"
    bad_words[:pharmaspam] = %w( propecia finasteride viagra )
    
    bad_words[:nigerian]   = ["million pounds sterling", "dear sirs,", "any bank account", "winning notification", "western union", "diagnosed with cancer", "bank treasury", "unclaimed inheritance"]

    # linkspammers
    bad_words[:linkspam] = ["increase traffic", "discovered your blog", "backlinks", "sent me a link", "more visitors to my site", "targeted traffic", "increase traffic to your website", "estore"]

    bad_words[:beats] = %w( beats dre headphones sale cheap shipping ) << "monster beats" << "best online"
    bad_words[:rolex] = %w( rolex watch replica watches price ) 
    bad_words[:wtf] = %w( bilete avion )
    
    # buying fake shitty brand stuff
    bad_words[:bagspam]  = %w(handbag louis louisvuitton vuitton chanel coach clearance outlet hermes bag scarf sale ralphlauren)
    bad_words[:handbags] = %w( karenmillen michaelkors kors millen bags purchase handbag chanel outlet tasche longchamp kaufen louboutin christianlouboutin)
    bad_words[:blingspam] = %w( tiffany jewellery tiffanyco clearance outlet)
    bad_words[:uggspam]  = %w(\buggs?\b \buggboots\b clearance outlet )
    bad_words[:wedding]  = ["wedding", "wedding dress", "weddingdress", "strapless"]
    
    bad_words[:webcamspam] = %w( live girls webcam adult singles) << "chat room"
    bad_words[:gamereview] = %w( games-review-it.com game-reviews-online.com )
    bad_words[:streaming]  = %w( watchmlbbaseball watchnhlhockey pspnsportstv.com )

    bad_words[:forum_spam] = ["IMG", "url="]

    suspicious_words =  %w( free buy galleries dating gallery hard hardcore video homemade celebrity ) << "credit card" << "my friend" << "friend sent me"
    suspicious_words |= %w( adult overnight shipping free hot movie nylon arab ?????? seo)
    suspicious_words << "forums/member.php?u=" << "chat room" << "free chat" << "yahoo chat" << "page.php"
    
    bad_words.each do |key,wordlist|
      counter = 0
      wordlist.each do |word|
        results = Regexp.new("\\b(#{word})\\b").match @body
        if results && results.size > 0
          counter += 1
          add_score((self.class.bad_word_score ** results.size), "nasty word: '#{word}'")

          # Add more points if the bad word is INSIDE a link
          @body.scan(/<a[^>]+>(.*?)<\/a>/).each do |match|
            add_score self.class.bad_word_score * 10 * match[0].scan(word).size, "nasty word inside a link: #{word}"
          end
          @body.scan(/\nhttp:\/\/(.*?#{word})\//).each do |match|
            add_score self.class.bad_word_score * 10 * match[0].scan(word).size, "nasty word inside a straight-up link: #{word}"
          end
          @body.scan(/<a.*?>(.*?)<\/a>/).each do |links|
            add_score self.class.bad_word_score * 50, "nasty word is the entire link: #{word}"
          end
          @body.scan(/<a(.*?)>/).each do |match|
            add_score self.class.bad_word_score * 10 * match[0].scan(word).size, "nasty word inside a URL: #{word}"
          end
        end
        if counter > (wordlist.size / 2)
          add_score 1000, "Lots of bad words from one genre (#{key}): #{counter}"
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
