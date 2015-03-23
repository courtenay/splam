# encoding: UTF-8
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
    bad_words[:pornspam] << /pel?cula/ << /pornogr?fica/ << /er[o0]tic[oa]?/ << /er[0o]tismo/ << "portal porno" # srsly, spamming in spanish?
    bad_words[:pornspam] |= %w( webcam  free-web-host rapidshare)
    
    bad_words[:callgirls] = [/(s[ℰⅇe]xy\s+|[ℂc]a[lℓℒ][lℓℒ]\s+)?[Gg][ℐi][rℜℝℛ][lℓℒ]s?/i, /[Eℰⅇℯe][Ss][ℭℂc][0ℴo][ℜℝℛr.][풕Tt]s?/i]
    bad_words[:callgirls] << /[+0]?971[ -]?557[ -]?928[ -]?406/
    bad_words[:ejaculation] = %w(ejaculation) << "premature ejaculation"

    bad_words[:viagraspam] = %w( cialis viagra pharmacy prescription levitra kamagra)
    bad_words[:benzospam]  = %w( ultram tramadol pharmacy prescription )
    bad_words[:cashspam]   = %w( payday loan jihad ) << "payday loan" << /jihad/
    bad_words[:pharmaspam] = %w( xanax propecia finasteride viagra )
    
    bad_words[:nigerian]   = ["million pounds sterling", "dear sirs,", "any bank account", "winning notification", "western union", "diagnosed with cancer", "bank treasury", "unclaimed inheritance"]

    # linkspammers
    bad_words[:linkspam] = ["increase traffic", "discovered your blog", "backlinks", "sent me a link", "more visitors to my site", "targeted traffic", "increase traffic to your website", "estore"]

    bad_words[:beats] = %w( beats dre headphones sale cheap ) << "monster beats" << "best online"
    bad_words[:rolex] = %w( rolex watch replica watches oriflame ) 
    bad_words[:wtf] = %w( bilete avion )
    
    # buying fake shitty brand stuff
    bad_words[:bagspam]  = %w(handbag louis louisvuitton vuitton chanel coach clearance outlet hermes bag scarf sale ralphlauren)
    bad_words[:handbags] = %w( karenmillen michaelkors kors millen bags handbag chanel outlet tasche longchamp kaufen louboutin christianlouboutin)
    bad_words[:blingspam] = %w( tiffany jewellery tiffanyco clearance outlet)
    bad_words[:uggspam]  = %w(\buggs?\b \buggboots\b clearance outlet)
    bad_words[:wedding]  = ["wedding", "wedding dress", "weddingdress", "strapless"]

    bad_words[:webcamspam] = %w( girls webcam adult singles) << /chat rooms?/
    bad_words[:gamereview] = %w( games-review-it.com game-reviews-online.com )
    bad_words[:streaming]  = %w( watchmlbbaseball watchnhlhockey pspnsportstv.com )

    bad_words[:bamwar] = [/bam[ <()>]*war[ <()>]*com/]

    suspicious_words =  %w( free buy galleries dating gallery hard hardcore video homemade celebrity ) << "credit card" << "my friend" << "friend sent me"
    suspicious_words |= %w( adult overnight free hot movie nylon arab ?????? seo generic live online)
    suspicious_words << "forums/member.php?u=" << "chat room" << "free chat" << "yahoo chat" << "page.php"


    bad_words.each do |key,wordlist|
      counter = 0
      body = @body.downcase
      wordlist.each do |word|
        regex = word.is_a?(Regexp) ? word : Regexp.new("\\b(#{word})\\b","i")
        results = body.scan(regex)
        if results && results.size > 0
          counter += 1
          multiplier = results.size
          multiplier = 5 if results.size > 5
          add_score((self.class.bad_word_score ** multiplier), "nasty word (#{multiplier}x): '#{word}'")
          # Add more points if the bad word is INSIDE a link
          body.scan(/<a[^>]+>(.*?)<\/a>/).each do |match|
            add_score self.class.bad_word_score ** 4 * multiplier, "nasty word inside a link: #{word}"
          end
          body.scan(/\bhttp:\/\/(.*?#{word})/).each do |match|
            add_score self.class.bad_word_score ** 4 * match[0].scan(word).size, "nasty word inside a straight-up link: #{word}"
          end
          body.scan(/<a(.*?)>/).each do |match|
            add_score self.class.bad_word_score ** 4 * match[0].scan(word).size, "nasty word inside a URL: #{word}"
          end
        end
        if counter > (wordlist.size / 2)
          add_score 50, "Lots of bad words from one genre (#{key}): #{counter}"
        end
      end
    end
    suspicious_words.each do |word|
      results = body.scan(word)
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
