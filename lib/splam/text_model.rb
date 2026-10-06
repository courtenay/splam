# encoding: UTF-8
# A Naive Bayes text model trained on labelled documents, for any language:
# word unigrams and trigrams, and character pairs for Chinese and Japanese,
# which have no spaces between words. Counts live in a store (MemoryStore, or
# RedisStore for an app's own corpus).
#
#   model = Splam::TextModel.new(Splam::TextModel::RedisStore.new(redis, "splam:site:42"))
#   model.train(comment.id, text, :spam)   # staff marked it spam
#   model.train(comment.id, text, :ham)    # ...then restored it: counts move
#   model.score(text)                      # => { :log_odds => -2.1, :probability => 0.11, ... }
#
# Training is keyed by document id, so training a document again with the
# same label does nothing and a new label moves its counts once. Untraining
# uses the text it's given, so if a document's text changed after training,
# its old counts can't be taken back exactly; counts never go below zero, and
# rebuilding the store from the labels is the remedy for any drift.
class Splam::TextModel
  LABELS = [:spam, :ham]

  # Han, Hiragana, Katakana: a run of them is split into character pairs
  CJK = /[\p{Han}\p{Hiragana}\p{Katakana}]+/
  WORD = /[[:alnum:]]+(?:'[[:alnum:]]+)*/

  attr_reader :store, :alpha, :max_chars

  # alpha: Laplace smoothing. max_chars: the text considered, from the start,
  # the same for training and scoring.
  def initialize(store, options = {})
    @store = store
    @alpha = (options[:alpha] || 1.0).to_f
    @max_chars = options[:max_chars] || 1000
  end

  # The features of a text and how often each occurs: "w:word" unigrams,
  # "t:a b c" word trigrams, "c:xy" CJK character pairs.
  def features(text)
    text = text.to_s
    text = text.scrub('') unless text.valid_encoding?
    text = text[0, @max_chars].downcase
    counts = Hash.new(0)
    words = []
    text.scan(/#{CJK}|#{WORD}/o) do
      token = $&
      if token =~ /\A#{CJK}\z/o
        if token.size == 1
          counts["c:#{token}"] += 1
        else
          (0...token.size - 1).each { |i| counts["c:#{token[i, 2]}"] += 1 }
        end
        words << token
      else
        counts["w:#{token}"] += 1
        words << token
      end
    end
    (0...words.size - 2).each { |i| counts["t:#{words[i]} #{words[i + 1]} #{words[i + 2]}"] += 1 }
    counts
  end

  # label: :spam, :ham, or nil to forget the document
  def train(doc_id, text, label)
    label = label && label.to_sym
    raise ArgumentError, "label must be :spam, :ham or nil" unless label.nil? || LABELS.include?(label)
    old = @store.label(doc_id)
    old = old && old.to_sym
    return false if old == label
    counts = features(text)
    @store.add(old, counts, -1) if old
    @store.add(label, counts, 1) if label
    @store.set_label(doc_id, label)
    true
  end

  # :log_odds (natural log of P(spam|text) / P(ham|text)), :probability, the
  # features that pushed it most each way, and how many were never seen.
  def score(text)
    counts = features(text)
    meta = @store.meta
    docs = { :spam => meta["spam_docs"].to_i, :ham => meta["ham_docs"].to_i }
    return neutral(counts) if docs[:spam].zero? || docs[:ham].zero? || counts.empty?
    keys = counts.keys
    found = { :spam => @store.counts(:spam, keys), :ham => @store.counts(:ham, keys) }
    totals = { :spam => meta["spam_tokens"].to_i, :ham => meta["ham_tokens"].to_i }
    vocab = [meta["spam_vocab"].to_i + meta["ham_vocab"].to_i, 1].max
    log_odds = Math.log(docs[:spam].to_f / docs[:ham])
    contributions = []
    unknown = 0
    keys.each_with_index do |key, i|
      s, h = found[:spam][i], found[:ham][i]
      unknown += 1 if s.zero? && h.zero?
      p_s = (s + @alpha) / (totals[:spam] + @alpha * vocab)
      p_h = (h + @alpha) / (totals[:ham] + @alpha * vocab)
      c = counts[key] * Math.log(p_s / p_h)
      log_odds += c
      contributions << [key, c]
    end
    contributions.sort_by! { |_, c| -c }
    {
      :log_odds => log_odds,
      :probability => self.class.probability(log_odds),
      :spam_features => contributions.first(5).select { |_, c| c > 0 },
      :ham_features => contributions.last(5).reverse.select { |_, c| c < 0 },
      :features => keys.size,
      :unknown => unknown,
    }
  end

  # 1 / (1 + e^-x), without overflowing Math.exp for large |x|
  def self.probability(log_odds)
    x = [[log_odds, 700.0].min, -700.0].max
    1.0 / (1.0 + Math.exp(-x))
  end

  def stats
    meta = @store.meta
    Hash[%w(spam_docs ham_docs spam_tokens ham_tokens spam_vocab ham_vocab).map { |k| [k.to_sym, meta[k].to_i] }]
  end

  private

  def neutral(counts)
    { :log_odds => 0.0, :probability => 0.5, :spam_features => [], :ham_features => [], :features => counts.size, :unknown => counts.size }
  end

  # Counts in Ruby: for tests and offline evaluation.
  class MemoryStore
    def initialize
      @counts = { :spam => Hash.new(0), :ham => Hash.new(0) }
      @meta = Hash.new(0)
      @labels = {}
    end

    def counts(label, keys)
      keys.map { |k| @counts[label][k] }
    end

    def add(label, counts, sign)
      table = @counts[label]
      counts.each do |key, n|
        before = table[key]
        after = [before + sign * n, 0].max
        if after.zero?
          table.delete(key)
        else
          table[key] = after
        end
        @meta["#{label}_vocab"] += 1 if before.zero? && after > 0
        @meta["#{label}_vocab"] -= 1 if before > 0 && after.zero?
        @meta["#{label}_tokens"] += after - before
      end
      @meta["#{label}_docs"] = [@meta["#{label}_docs"] + sign, 0].max
    end

    def meta
      @meta
    end

    def label(doc_id)
      @labels[doc_id.to_s]
    end

    def set_label(doc_id, label)
      label ? @labels[doc_id.to_s] = label.to_s : @labels.delete(doc_id.to_s)
    end
  end

  # Counts in Redis hashes under one prefix: <prefix>:spam and <prefix>:ham
  # (feature => count), <prefix>:meta (doc, token and vocabulary counts) and
  # <prefix>:labels (doc id => label). A score is one HMGET per label plus the
  # meta hash; nothing reads a whole hash.
  class RedisStore
    # never below zero; returns [before, after]
    ADD = <<-LUA
      local before = tonumber(redis.call('HGET', KEYS[1], ARGV[1]) or '0')
      local after = before + tonumber(ARGV[2])
      if after < 0 then after = 0 end
      if after == 0 then redis.call('HDEL', KEYS[1], ARGV[1]) else redis.call('HSET', KEYS[1], ARGV[1], after) end
      return {before, after}
    LUA

    def initialize(redis, prefix)
      @redis, @prefix = redis, prefix
    end

    def counts(label, keys)
      return [] if keys.empty?
      @redis.hmget("#{@prefix}:#{label}", *keys).map(&:to_i)
    end

    def add(label, counts, sign)
      key = "#{@prefix}:#{label}"
      vocab = tokens = 0
      results = @redis.pipelined do |pipe|
        counts.each { |feature, n| pipe.eval(ADD, [key], [feature, sign * n]) }
      end
      results.each do |before, after|
        before, after = before.to_i, after.to_i
        vocab += 1 if before.zero? && after > 0
        vocab -= 1 if before > 0 && after.zero?
        tokens += after - before
      end
      meta = "#{@prefix}:meta"
      @redis.pipelined do |pipe|
        pipe.hincrby(meta, "#{label}_vocab", vocab) unless vocab.zero?
        pipe.hincrby(meta, "#{label}_tokens", tokens) unless tokens.zero?
        pipe.hincrby(meta, "#{label}_docs", sign)
      end
    end

    def meta
      @redis.hgetall("#{@prefix}:meta") # a handful of fields
    end

    def label(doc_id)
      @redis.hget("#{@prefix}:labels", doc_id.to_s)
    end

    def set_label(doc_id, label)
      if label
        @redis.hset("#{@prefix}:labels", doc_id.to_s, label.to_s)
      else
        @redis.hdel("#{@prefix}:labels", doc_id.to_s)
      end
    end
  end
end

