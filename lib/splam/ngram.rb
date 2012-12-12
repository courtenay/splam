class Splam::Ngram

  def self.trigram text
    # this won't be utf-8 happy. Oh well!
    words = text.gsub("'", "").split(/\W/)
    hash = Hash.new 0
    i = 0
    while (i < words.length)
      tri = []
      count = 0
      while ((words.length > i + count) && (tri.length < 3))
        word = words[i + count]
        if word && word != ""
          tri << words[i + count]
        end
        count += 1
      end
      if tri.length == 3
        hash[tri.join(' ')] += 1
      end
      i += 1
    end
    hash
  end

  def initialize site_id=nil
    @site_id = site_id
  end

  # Train the temporary corpus with your data
  def train words, spam = false, retrain = false
    if words.is_a?(String)
      words = self.class.trigram(words)
    end
    words.each do |word,value|
      key = spam ? "spam" : "ham"
      REDIS.hincrby key, word, value
      REDIS.hincrby "#{key}-#{@site_id}", word, value if @site_id
      if retrain
        # Remove phrases from existing corpus
        key = spam ? "ham" : "spam"
        REDIS.hincrby key, word, -value
        REDIS.hincrby "#{key}-#{@site_id}", word, -value if @site_id
      end
    end
  end
  
  def compare text
    tri = self.class.trigram(text)
    score = 0
    spam = 0
    
    ham_key = @site_id ? "ham-#{@site_id}" : "ham"
    spam_key = @site_id ? "spam-#{@site_id}" : "spam"

    @ham_tri = Hash.new 0
    @spam_tri = Hash.new 0

    tri.each do |key,value|
      next if key.nil? || key.strip == ""
      hmatch = REDIS.hget(ham_key, key).to_i #  ham_tri[key]
      smatch = REDIS.hget(spam_key, key).to_i  # spam_tri[key]

      if hmatch > 0 && smatch > 0
        # tri appears in both
        # ignore.
        next
      end
      if hmatch > 0
        score += hmatch + value
      elsif smatch > 0
        spam += smatch + value
      end
    end
    [score, spam]
  end
end

# corpus = Splam::Ngram.new 10009
# s.comments.paginated_each(:order => "id desc") do |c| 
#   puts c.id
#   words = Splam::Ngram.trigram(c.body.downcase)
#   if c.author.support? || (c.user && c.user.trusted?)
#     corpus.train words, false
#   elsif c.spam
#     corpus.train words, true
#   end
# end
# 
# Comment.spam.paginated_each(:order => "id desc", :conditions => ['id < 12916619']) do |c| 
#   next if c.user_email == "no-reply@lighthouseapp.com"
#   score = corpus.compare(c.body)
#   if score[0] > score[1]
#     puts "Not spam? #{c.id} : #{score.inspect} - #{c.body.first(100)}"
#   else
#     puts "Spam! #{c.id} : #{score.inspect}"
#   end
# end