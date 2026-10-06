# The rules' link scans, /<a[^>]+>(.*?)<\/a>/ and friends, give up and
# restart one character later whenever a "<a" has no ">" or "</a>" after
# it, so "<a<a<a..." or "http://http://..." take quadratic time, and the
# rules run them inside the request that saves a comment. These find
# exactly what String#scan found with those regexes (the scores must not
# move: Job::CheckSpam compares them to fixed thresholds), but remember
# where each substring was last found, so a whole scan is linear.
module Splam::LinearScan
  # text.index(needle, pos) for increasing pos, reusing the last answer
  # while it's still ahead of pos. A Regexp needle gives MatchData.
  class Finder
    def initialize(text, needle)
      @text, @needle, @searched_from, @found = text, needle, nil, nil
    end

    def from(pos)
      if @searched_from.nil? || pos < @searched_from || (@found && start(@found) < pos)
        @searched_from = pos
        @found = @needle.is_a?(Regexp) ? @text.match(@needle, pos) : @text.index(@needle, pos)
      end
      @found
    end

    private

    def start(found)
      found.is_a?(MatchData) ? found.begin(0) : found
    end
  end

  # Finder for /#{first}.*?#{last}/ with literal strings. Matching that
  # regex from pos restarts at every "first" up to the end of the line, so
  # it's quadratic on a line of them; this takes the leftmost "first" on
  # each line that has a "last" after it.
  class PairFinder
    Match = Struct.new(:first, :last) do
      def begin(_); first; end
      def end(_); last; end
    end

    def initialize(text, first, last)
      @opening, @closing, @nl = Finder.new(text, first), Finder.new(text, last), Finder.new(text, "\n")
      @first_size, @last_size = first.size, last.size
      @searched_from = @found = nil
    end

    def from(pos)
      if @searched_from.nil? || pos < @searched_from || (@found && @found.first < pos)
        @searched_from = pos
        @found = search(pos)
      end
      @found
    end

    private

    def search(pos)
      while (i = @opening.from(pos))
        e = @closing.from(i + @first_size) or return
        n = @nl.from(i + @first_size)
        return Match.new(i, e + @last_size) if n.nil? || n >= e
        pos = n + 1
      end
    end
  end

  module_function

  # text.scan(/<a[^>]+>(.*?)<\/a>/)
  def link_texts(text)
    opening, gt, closing, nl = finders(text, '<a', '>', '</a>', "\n")
    results, pos = [], 0
    while (i = opening.from(pos))
      k = gt.from(i + 2)
      if k && k > i + 2 && (e = closing.from(k + 1)) && no_newline_before?(nl, k + 1, e)
        results << [text[(k + 1)...e]]
        pos = e + 4
      else
        pos = i + 1
      end
    end
    results
  end

  # text.scan(/<a(.*?)>/)
  def link_attributes(text)
    opening, gt, nl = finders(text, '<a', '>', "\n")
    results, pos = [], 0
    while (i = opening.from(pos))
      if (k = gt.from(i + 2)) && no_newline_before?(nl, i + 2, k)
        results << [text[(i + 2)...k]]
        pos = k + 1
      else
        pos = i + 1
      end
    end
    results
  end

  # text.scan(/<a[^>]*><b>/).size
  def bold_link_count(text)
    opening, gt = finders(text, '<a', '>')
    count, pos = 0, 0
    while (i = opening.from(pos))
      k = gt.from(i + 2)
      if k && text[k + 1, 3] == '<b>'
        count += 1
        pos = k + 4
      else
        pos = i + 1
      end
    end
    count
  end

  # text.scan(/\bhttp:\/\/(.*?#{word})/); a [first, last] pair of strings
  # stands for the word /#{first}.*?#{last}/
  def http_links_to(text, word)
    http, nl = finders(text, 'http://', "\n")
    found = if word.is_a?(Array)
      PairFinder.new(text, *word)
    else
      Finder.new(text, word.is_a?(Regexp) ? word : Regexp.new(word.to_s))
    end
    results, pos = [], 0
    while (i = http.from(pos))
      if (i == 0 || text[i - 1, 2] =~ /\A.\bh/m) &&
         (m = found.from(i + 7)) && no_newline_before?(nl, i + 7, m.begin(0))
        results << [text[(i + 7)...m.end(0)]]
        pos = m.end(0)
      else
        pos = i + 1
      end
    end
    results
  end

  # text.scan(/#{first}.*?#{last}/) for literal strings
  def lazy_pairs(text, first, last)
    opening, closing, nl = finders(text, first, last, "\n")
    results, pos = [], 0
    while (i = opening.from(pos))
      if (e = closing.from(i + first.size)) && no_newline_before?(nl, i + first.size, e)
        results << text[i...(e + last.size)]
        pos = e + last.size
      else
        pos = i + 1
      end
    end
    results
  end

  def finders(text, *needles)
    needles.map { |needle| Finder.new(text, needle) }
  end

  # "." doesn't match a newline: nothing in text[from...to] may be one
  def no_newline_before?(nl, from, to)
    n = nl.from(from)
    n.nil? || n >= to
  end
end
