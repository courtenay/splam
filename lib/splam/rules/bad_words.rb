# encoding: UTF-8
class Splam::Rules::BadWords < Splam::Rule
  class << self
    attr_writer :bad_word_score
    attr_accessor :suspicious_word_score

    # set here to override Splam.config (10 by default, 15 in the :lighthouse profile)
    def bad_word_score
      @bad_word_score || Splam.config.bad_word_score
    end

    # A list entry (a regex fragment) as a case-insensitive Regexp, with \b on
    # each side that is a word character. Before 0.5 both sides always got \b,
    # so entries starting or ending in punctuation ("dear,", "<<<91") could
    # never match; every entry still matches what it matched then.
    def word_regex(word)
      lead = word =~ /\A[[:word:]]/ ? "\\b" : ""
      trail = word =~ /[[:word:]]\z/ ? "\\b" : ""
      Regexp.new("#{lead}(#{word})#{trail}", "i")
    end
  end

  self.suspicious_word_score = 4

  # scanned with Splam::LinearScan.lazy_pairs (quadratic as a regex)
  LOVE_SOLUTION = /love .*?solution/

  # The word genres (data/bad_words/*.txt; the :lighthouse profile adds
  # data/bad_words/lighthouse/*.txt) and the suspicious words
  # (data/suspicious_words.txt), read once per process.
  def self.lists(lighthouse)
    @lists ||= {}
    @lists[lighthouse] ||= begin
      genres = {}
      Dir[File.join(Splam::WordList::DIR, "bad_words", "*.txt")].sort.each do |path|
        genres[File.basename(path, ".txt").to_sym] = read_entries(path)
      end
      if lighthouse
        Dir[File.join(Splam::WordList::DIR, "bad_words", "lighthouse", "*.txt")].sort.each do |path|
          genre = File.basename(path, ".txt").to_sym
          genres[genre] = (genres[genre] || []) + read_entries(path)
        end
      end
      [genres, read_entries("suspicious_words.txt")]
    end
  end

  # love .*?solution is matched as a pair of strings (see #run), by identity
  def self.read_entries(path)
    Splam::WordList.read(path).map { |e| e == LOVE_SOLUTION ? LOVE_SOLUTION : e }
  end

  # word_regex, compiled once per entry
  def self.compiled(word)
    (@compiled ||= {})[word] ||= word_regex(word)
  end

  def run
    bad_words, suspicious_words = self.class.lists(Splam.config.feature?(:lighthouse_words))

    # The link scans are Splam::LinearScan's, done once per document (Splam::Document):
    # they were repeated for every matched word, each quadratic on "<a<a<a...".
    body = @document.downcased

    bad_words.each do |key,wordlist|
      counter = 0
      wordlist.each do |word|
        regex = word.is_a?(Regexp) ? word : self.class.compiled(word)
        # /love .*?solution/ is quadratic on a line of "love ", so it's
        # matched as the pair of strings everywhere
        pair = ["love ", "solution"] if word.equal?(LOVE_SOLUTION)
        count_in = lambda { |text| pair ? Splam::LinearScan.lazy_pairs(text, *pair).size : text.scan(word).size }
        results = pair ? Splam::LinearScan.lazy_pairs(body, *pair) : body.scan(regex)
        if results && results.size > 0
          counter += 1
          multiplier = results.size
          multiplier = 5 if results.size > 5
          add_score((self.class.bad_word_score ** multiplier), "nasty word (#{multiplier}x): '#{word}'")
          # Add more points if the bad word is INSIDE a link
          # (before 0.5 this scored every link on the page, word or not)
          @document.link_texts(true).each do |match|
            add_score self.class.bad_word_score ** 4 * count_in.call(match[0]), "nasty word inside a link: #{word}"
          end
          Splam::LinearScan.http_links_to(body, pair || word).each do |match|
            add_score self.class.bad_word_score ** 4 * count_in.call(match[0]), "nasty word inside a straight-up link: #{word}"
          end
          @document.link_attributes(true).each do |match|
            add_score self.class.bad_word_score ** 4 * count_in.call(match[0]), "nasty word inside a URL: #{word}"
          end
        end
      end
      # once per genre (before 0.5 it sat in the word loop and repeated for each later word)
      if counter > (wordlist.size / 2)
        add_score 50, "Lots of bad words from one genre (#{key}): #{counter}"
      end
    end
    suspicious_words.each do |word|
      results = @body.scan(word) # the original case: this was the #body reader, outside the block that lowercased it
      if results && results.size > 0
        add_score (self.class.suspicious_word_score * results.size), "suspicious word: #{word}"
        # Add more points if the bad word is INSIDE a link
        @document.link_texts.each do |match|
          add_score((self.class.suspicious_word_score * match[0].scan(word).size), "suspicious word inside a link: #{word}")
        end
      end
    end
  end
end
