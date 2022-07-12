# encoding: UTF-8
class Splam::Rules::BadWords < Splam::Rule
  class << self
    attr_accessor :bad_word_score, :suspicious_word_score
  end
  
  self.bad_word_score       = 15
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

    bad_words[:mandrugs] = %w( maleenhancement ) << "male improvement" << "sex drive" << "erection" <<
      "erections" << "libido" << "irresistable" << "orgasms" << "male energy" << "geneticore" << "supplements" <<
      "malemuscle" << "musclebuilding" << "muscle" << "male enhancement" << "erx"

    bad_words[:viagraspam] = %w( cialis viagra pharmacy prescription levitra kamagra)
    bad_words[:benzospam]  = %w( ultram tramadol pharmacy prescription )
    bad_words[:cashspam]   = %w( payday loan jihad ) << "payday loan" << /jihad/
    bad_words[:pharmaspam] = %w( xanax propecia finasteride viagra )
    
    bad_words[:nigerian]   = ["million pounds sterling", "dear sirs,", "any bank account", "winning notification", "western union", "diagnosed with cancer", "bank treasury", "unclaimed inheritance"]

    bad_words[:hormone] = ["testo", "testosterone", "muscle"]
    bad_words[:download] = ["jkb.download", "tax relief", "paroxyl.download", "/im/", ".download/im/", ".top/im/", ".top/l/", "download.php", ".site/"]
    bad_words[:futbol] = ["vslivestreamwatchtv", "watchvslivestreamtv", ".xyz", "livestreamtv", "livestreamwatch"]
    bad_words[:phero]  = ["pheromone", "pherone", "milligrams", "weight loss"]
    bad_words[:leadgen] = ["lead generation", "agile marketing", "marketing solutions", "please reply with STOP"]

    bad_words[:sms] = ["send free sms"]
    bad_words[:keto] = ["keto", "ketosis", "ketosis advanced", "keto diet", "keto burning", "diet", "pills", "bhb"]

    # linkspammers
    bad_words[:linkspam] = ["increase traffic", "discovered your blog", "backlinks", "sent me a link", "more visitors to my site", "targeted traffic", "increase traffic to your website", "estore"]
    bad_words[:support] = ["customer-support-number", "third party tech support team",
      "yahoo-support", "098-8579", "hp-printer-help", "yahoo customer service",
      "getting attached with", "1800-875-393", "0800-098-8371", "800-098-8372", /[+]44[-]800/,
      "800[-]098", /1[-]800[-]778/, /email-customerservice/, "yahoo experts", "1-800-778-9936",
      "844-292", "[+]1[-]844", "800[-]921",
      "facebook-support", "1-888-521-0120", "0800-090-3228", /0800[-]090/,
      /(dlink|asus|linksys|gmail|brother|lexmark|hp|apple|facebook|microsoft|google|yahoo|safari|office|outlook)-(chrome|printer|browser|technical|email|365|customer)-(support|service)/,
      "outlook-support", "888-201", "800-986-4764", "[(][+]1[)] 888", "[(][+]61[)] 1800",
      "1-800-778-9936", "[+]1-800-826-806", "866-324-3042",
      "supportnumberaustralia", "netgear router", "tutu app", "spotify premium apk",
      "advertising inquiry for", 
      "Microsoft Office 365 Technical Support", "gmail support", "helpline number",
      "MYOB support", "microsoftoutlookoffice", "emailonline", "onlinesupport",
      "customercarenumber", "support-australia", "norton360-support",
      /(Mac|Amazon|Amazon Prime|Norton Antivirus 360|AVG|garmin|Microsoft|Yahoo|Icloud|Kapersky Antivirus) (Tech Support|Support|Help|Customer Service|Customer Support) (Phone )?Number/,
      /Support Number [+]1[-]844/,
      "353-12544725",

      "Chrome Customer Care", "helpline number",
      "www.customer-helpnumber", "www.printer-customersupport",
      "www.email-customerservice",
      "www.customer", "www.printer", 


      "located in Bangalore"
    ]

    bad_words[:india] = %w(hyderabad kolkota jaipur bangalore chennai) << "packers and movers" << "mover" << "moving company"

    bad_words[:beats] = %w( beats dre headphones sale cheap ) << "monster beats" << "best online"
    bad_words[:rolex] = %w( rolex replica watches oriflame ) 
    bad_words[:wtf] = %w( bilete avion )
    bad_words[:lawyer] = ["personal injury lawyer", "advertizement"]
    
    # buying fake shitty brand stuff
    bad_words[:bagspam]  = %w(handbag louis louisvuitton vuitton chanel coach clearance outlet hermes bag scarf sale ralphlauren)
    bad_words[:handbags] = %w( karenmillen michaelkors kors millen bags handbag chanel outlet tasche longchamp kaufen louboutin christianlouboutin)
    bad_words[:blingspam] = %w( tiffany jewellery tiffanyco clearance outlet)

    bad_words[:drugz] = %w(cbd hemp cannabis gummies)
    bad_words[:diet] = ["nutritional information", "diet pills", "weight loss", "potions", "breast enlargement", "enlargement pills"]
    bad_words[:uggspam]  = %w(\buggs?\b \buggboots\b clearance outlet)
    bad_words[:wedding]  = ["wedding", "wedding dress", "weddingdress", "strapless"]

    bad_words[:shoes] = ["Nike free", "Air max", "Valentino shoes", "Free run", "Nike", "Lebron James"]
    bad_words[:mover] = ["Shifting", "Packing", "movers", "bangalore"]
    bad_words[:hellofriend] = ["hello friend", "I found some new stuff", "dear,", "that might be useful for you"]

    bad_words[:webcamspam] = %w( girls webcam adult singles) << /chat room(s?)/
    bad_words[:gamereview] = %w( games-review-it.com game-reviews-online.com )
    bad_words[:streaming]  = %w( watchmlbbaseball watchnhlhockey pspnsportstv.com )

    bad_words[:lh]   =%w( coupon free buy galleries dating gallery hard hardcore video homemade celebrity ) << "credit card" << "my friend" << "friend sent me"
    bad_words[:lh_2] = %w( adult pharmacy overnight shipping free hot movie nylon arab  xxx) << "sent me a link"
    bad_words[:lh_3] = %w( usa jersey nfl classified classifieds disney furniture camera gifts.com mp5 ) << "flash drive"

    bad_words[:forum_spam] = ["IMG", "url="]

    bad_words[:adblock] = %w(8107764125 9958091843 9783565359 vashikaran vashi karan vas hikarn vash ikaran punjab pondicherry kerala) << "voodoo" << "love marriage" << "love problem" <<
      /\+91/ << "baba ji" << "babaji" << "<<<91" << "thailand" << /love .*?solution/ <<
      "astrologer expert" << /black magi[ck]/ << /love spells?/ << /healing spells?/ << "ex wife"

    bad_words[:bamwar] = [/bam[ <()>]*war[ <()>]*com/]

    suspicious_words =  %w( free buy galleries dating gallery hard hardcore homemade celebrity ) << "credit card" << "my friend" << "friend sent me"
    suspicious_words |= %w( adult overnight free hot movie nylon arab ?????? seo generic live online)
    suspicious_words << "forums/member.php?u=" << "chat room" << "free chat" << "yahoo chat" << "page.php"

    bad_words[:dumps] = %w( dumps okta )


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
