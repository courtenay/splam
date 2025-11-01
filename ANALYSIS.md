# Splam: Analysis & Improvement Opportunities

## Executive Summary

Splam is a robust rule-based spam detection system that has been battle-tested in production. However, there are several opportunities to modernize the system with statistical methods, machine learning, and architectural improvements that could significantly enhance accuracy while reducing maintenance overhead.

## Current Architecture Analysis

### Strengths

1. **Modular Design**: Clean separation of rules makes it easy to add/remove detection strategies
2. **Production-Proven**: Real-world spam corpus (48 samples) shows it handles diverse spam types
3. **Extensible**: Simple API for adding custom rules
4. **Fast**: Lightweight heuristics run quickly
5. **Transparent**: Scoring reasons make debugging straightforward
6. **No Dependencies**: Minimal external dependencies (just ActiveSupport)

### Weaknesses

1. **Static Rules**: Hardcoded patterns don't adapt to evolving spam
2. **Manual Tuning**: Requires constant updates as spam tactics change
3. **No Learning**: Doesn't improve from feedback (false positives/negatives)
4. **Score Calibration**: Arbitrary point values across rules make tuning difficult
5. **Limited Context**: Doesn't consider user reputation history deeply
6. **No Ensemble**: Rules operate independently without coordination
7. **Binary Features**: Most rules use binary detection (present/absent) rather than statistical significance

## Improvement Opportunities

### 1. Statistical & Machine Learning Enhancements

#### A. Bayesian Spam Filtering (High Priority)

**Current State**: Basic ngram system exists but is barely used

**Opportunity**: Implement proper Naive Bayes classifier
- Already have trigram infrastructure in `ngram.rb`
- Currently only used by `TokenUniqueness` rule
- Could replace many hardcoded rules with trained model

**Implementation**:
```ruby
class Splam::Rules::BayesianFilter < Splam::Rule
  def run
    return unless defined?(REDIS)

    corpus = Splam::Ngram.new(@suite.site_id)
    ham_score, spam_score = corpus.compare(@body)

    if spam_score > ham_score
      probability = spam_score.to_f / (spam_score + ham_score)
      points = (probability * 200).to_i  # 0-200 scale
      add_score points, "Bayesian spam probability: #{(probability * 100).round}%"
    else
      # Reduce score for likely ham
      probability = ham_score.to_f / (spam_score + ham_score)
      reduction = (probability * 50).to_i
      add_score -reduction, "Bayesian ham probability: #{(probability * 100).round}%"
    end
  end
end
```

**Benefits**:
- Adapts to new spam patterns automatically
- Learns from feedback
- Language-agnostic
- Reduces maintenance

**Effort**: Medium (infrastructure exists, needs enhancement)

---

#### B. TF-IDF Feature Extraction

**Opportunity**: Replace binary word matching with statistical relevance

**Current Problem**: Rules treat all word occurrences equally
```ruby
# Current: Binary detection
add_score 15, "Found viagra" if @body =~ /viagra/
```

**Better Approach**: Use TF-IDF to weight terms by importance
```ruby
class Splam::Rules::TfIdf < Splam::Rule
  def run
    # Calculate term frequency in this document
    terms = extract_terms(@body)

    terms.each do |term, tf|
      # Get inverse document frequency from corpus
      idf = get_idf(term)
      tfidf = tf * idf

      # Terms rare in ham but common in spam score high
      if spam_indicator?(term)
        add_score (tfidf * 10).to_i, "High TF-IDF for spam term: #{term}"
      end
    end
  end

  def extract_terms(text)
    # Tokenize and count
    words = text.downcase.scan(/\w+/)
    words.each_with_object(Hash.new(0)) { |word, counts| counts[word] += 1 }
  end

  def get_idf(term)
    # Query from corpus: log(total_docs / docs_with_term)
    # Cache these values
  end
end
```

**Benefits**:
- Distinguishes important vs common words
- Reduces false positives on common words
- Statistical foundation

**Effort**: Medium

---

#### C. Logistic Regression Meta-Classifier

**Opportunity**: Learn optimal rule weights from training data

**Current Problem**: Rule weights are manually tuned
```ruby
splammable :body do |suite|
  suite.rules = {
    Splam::Rules::BadWords => 2.0,  # Why 2.0? Gut feeling?
    Splam::Rules::Href => 0.5
  }
end
```

**Better Approach**: Use logistic regression to learn weights
```ruby
# Training phase
trainer = Splam::MetaClassifier.new
trainer.train_from_fixtures  # Uses test/fixtures/comment/{spam,ham}

# Generates optimal weights like:
# { BadWords: 1.8, Href: 0.7, Russian: 0.3, ... }

# Production usage
splammable :body do |suite|
  suite.rules = Splam::MetaClassifier.optimal_weights
end
```

**Implementation**:
- Collect feature vector from each rule
- Train logistic regression on labeled data
- Output optimal rule weights
- Can be retrained as new spam arrives

**Benefits**:
- Data-driven weight optimization
- Adapts to changing spam patterns
- Reduces manual tuning

**Effort**: Medium-High

---

### 2. Feature Engineering Improvements

#### A. Entropy Analysis

**Opportunity**: Measure text randomness to detect obfuscation

```ruby
class Splam::Rules::Entropy < Splam::Rule
  def run
    entropy = calculate_shannon_entropy(@body)

    # Very low entropy = repetitive (spam characteristic)
    if entropy < 2.5
      add_score 30, "Low entropy (#{entropy.round(2)}): repetitive text"
    # Very high entropy = random chars (obfuscation)
    elsif entropy > 4.5
      add_score 40, "High entropy (#{entropy.round(2)}): random text"
    end
  end

  def calculate_shannon_entropy(text)
    return 0 if text.empty?

    # Count character frequencies
    frequencies = Hash.new(0)
    text.each_char { |c| frequencies[c] += 1 }

    # Calculate entropy
    total = text.length.to_f
    -frequencies.values.sum { |freq|
      p = freq / total
      p * Math.log2(p)
    }
  end
end
```

**Benefits**:
- Detects character substitution obfuscation
- Detects random character spam
- Hard for spammers to evade

---

#### B. Levenshtein Distance for Template Detection

**Opportunity**: Detect spam variations using string similarity

```ruby
class Splam::Rules::SpamTemplate < Splam::Rule
  # Known spam templates (can be learned from corpus)
  TEMPLATES = [
    "click here to see amazing product",
    "limited time offer call now",
    # etc
  ]

  def run
    TEMPLATES.each do |template|
      distance = levenshtein_distance(@body.downcase, template)
      similarity = 1.0 - (distance.to_f / [template.length, @body.length].max)

      if similarity > 0.7
        add_score (similarity * 100).to_i, "Similar to known spam template (#{(similarity * 100).round}%)"
      end
    end
  end

  def levenshtein_distance(s1, s2)
    # Standard Levenshtein implementation
    # ... (omitted for brevity)
  end
end
```

**Benefits**:
- Catches spam variations
- Template library can grow over time
- Resilient to minor changes

---

#### C. Readability Scores

**Opportunity**: Spam often has poor grammar/readability

```ruby
class Splam::Rules::Readability < Splam::Rule
  def run
    # Flesch-Kincaid Grade Level
    grade_level = calculate_flesch_kincaid(@body)

    # Extremely low (< 0) or high (> 18) suggests non-human text
    if grade_level < 0
      add_score 20, "Abnormally low readability score"
    elsif grade_level > 18
      add_score 30, "Abnormally high readability score"
    end

    # Calculate type-token ratio (vocabulary diversity)
    ttr = type_token_ratio(@body)
    if ttr < 0.3
      add_score 20, "Low vocabulary diversity (#{(ttr * 100).round}%)"
    end
  end

  def calculate_flesch_kincaid(text)
    sentences = text.split(/[.!?]+/).reject(&:empty?)
    words = text.split(/\s+/)
    syllables = words.sum { |w| count_syllables(w) }

    return 0 if sentences.empty? || words.empty?

    206.835 - 1.015 * (words.size / sentences.size.to_f) - 84.6 * (syllables / words.size.to_f)
  end

  def type_token_ratio(text)
    words = text.downcase.scan(/\w+/)
    return 0 if words.empty?
    words.uniq.size.to_f / words.size
  end
end
```

**Benefits**:
- Catches machine-generated text
- Detects low-quality content
- Language-appropriate

---

#### D. Time-Based Features

**Opportunity**: Spam patterns vary by time of day

```ruby
class Splam::Rules::TemporalPatterns < Splam::Rule
  def run
    return unless @request && @request[:timestamp]

    hour = @request[:timestamp].hour

    # Most spam arrives 2-6 AM (when admins asleep)
    if hour >= 2 && hour <= 6
      add_score 15, "Posted during typical spam hours (#{hour}:00)"
    end

    # Check posting velocity (requires user history)
    if @user && @user.respond_to?(:recent_posts)
      posts_last_hour = @user.recent_posts(1.hour)
      posts_last_day = @user.recent_posts(24.hours)

      if posts_last_hour > 10
        add_score 100, "Extreme posting velocity: #{posts_last_hour}/hour"
      elsif posts_last_hour > 5
        add_score 50, "High posting velocity: #{posts_last_hour}/hour"
      end

      # Burst detection
      if posts_last_day > 50
        add_score 75, "Posting burst: #{posts_last_day} posts in 24h"
      end
    end
  end
end
```

---

### 3. Architectural Improvements

#### A. Score Normalization

**Current Problem**: Rules use arbitrary point scales

**Solution**: Normalize all rule scores to 0-1 probability scale

```ruby
class Splam::Rule
  # Instead of arbitrary points, return probability
  def add_probability(probability, reason)
    raise ArgumentError unless probability.between?(0, 1)
    @probabilities ||= []
    @probabilities << [probability, reason]
  end
end

class Splam::Suite
  def run(record, request)
    probabilities = []

    rules.each do |rule_class, weight|
      worker = rule_class.run(self, record, weight, request)
      probabilities.concat(worker.probabilities)
    end

    # Combine probabilities using ensemble method
    combined_prob = combine_probabilities(probabilities)

    # Convert to 0-1000 scale for backward compatibility
    score = (combined_prob * 1000).to_i
    [score, probabilities.map(&:last)]
  end

  def combine_probabilities(probs)
    # Naive Bayes combination (assumes independence)
    # P(spam | features) = P(features | spam) * P(spam) / P(features)

    # Or use Fisher's method for combining p-values
    # Or averaging
    # Or max
    probs.map(&:first).sum / probs.size.to_f
  end
end
```

**Benefits**:
- Consistent scoring across rules
- Mathematically sound combination
- Easier to reason about
- Can use standard probability methods

---

#### B. Rule Performance Tracking

**Opportunity**: Measure which rules are effective

```ruby
class Splam::RuleMetrics
  # Track rule effectiveness
  def self.track(rule_name, score, actual_spam)
    REDIS.hincrby "rule_metrics:#{rule_name}:total", 1
    REDIS.hincrby "rule_metrics:#{rule_name}:true_positives", 1 if score > 0 && actual_spam
    REDIS.hincrby "rule_metrics:#{rule_name}:false_positives", 1 if score > 0 && !actual_spam
    REDIS.hincrby "rule_metrics:#{rule_name}:false_negatives", 1 if score <= 0 && actual_spam
  end

  def self.report(rule_name)
    metrics = REDIS.hgetall("rule_metrics:#{rule_name}")
    {
      precision: metrics[:true_positives] / (metrics[:true_positives] + metrics[:false_positives]),
      recall: metrics[:true_positives] / (metrics[:true_positives] + metrics[:false_negatives]),
      # etc
    }
  end
end

# After spam/ham determination, record feedback
comment.mark_as_spam!
Splam::RuleMetrics.track_result(comment, comment.splam_reasons)
```

**Benefits**:
- Identify ineffective rules
- Optimize rule weights based on performance
- Justify resource allocation
- A/B testing

---

#### C. Feedback Loop & Active Learning

**Opportunity**: Learn from user corrections

```ruby
class Splam::FeedbackLoop
  def self.record_false_positive(content, reasons)
    # Store in database
    FalsePositive.create!(
      content: content,
      spam_score: content.splam_score,
      reasons: reasons
    )

    # If using Bayesian filter, retrain
    corpus = Splam::Ngram.new
    corpus.train(content.body, false, retrain: true)  # Mark as ham

    # Extract patterns that triggered false positive
    analyze_false_positive(content, reasons)
  end

  def self.record_false_negative(content)
    # Store spam that wasn't caught
    FalseNegative.create!(content: content)

    # Retrain
    corpus = Splam::Ngram.new
    corpus.train(content.body, true)  # Mark as spam

    # Suggest new rules
    suggest_rules_for_missed_spam(content)
  end

  def self.suggest_rules_for_missed_spam(content)
    # Analyze what patterns the spam had that weren't caught
    # E.g., extract URLs, unusual unicode, etc.
    # Log suggestions for human review
  end
end
```

**Benefits**:
- Continuous improvement
- Adapts to new spam
- Reduces maintenance burden

---

### 4. Modern Spam Patterns to Address

#### A. Unicode Obfuscation

**Problem**: Spammers use look-alike Unicode characters

```ruby
class Splam::Rules::UnicodeObfuscation < Splam::Rule
  CONFUSABLES = {
    'a' => %w(а ɑ α а),  # Latin a, Cyrillic a, Greek alpha, etc.
    'e' => %w(е ℮ ė),
    'o' => %w(о ο ο),
    # etc.
  }

  def run
    normalized = normalize_confusables(@body)

    if normalized != @body
      changes = levenshtein_distance(@body, normalized)
      add_score changes * 5, "Unicode confusables detected (#{changes} chars)"

      # Check if normalized version matches spam patterns
      @normalized_body = normalized
      check_bad_words_on_normalized
    end
  end
end
```

---

#### B. Image/Emoji Spam

**Problem**: Spam hidden in image-based text or emoji patterns

```ruby
class Splam::Rules::EmojiPatterns < Splam::Rule
  def run
    emoji_count = @body.scan(/[\u{1F300}-\u{1F9FF}]/).size

    if emoji_count > 5
      add_score emoji_count * 3, "Excessive emojis: #{emoji_count}"
    end

    # Detect emoji-only messages (common in crypto spam)
    words = @body.scan(/\w+/)
    if emoji_count > words.size && emoji_count > 3
      add_score 50, "Emoji-to-word ratio suspicious"
    end
  end
end
```

---

#### C. Zero-Width Characters

**Problem**: Hidden text using zero-width characters

```ruby
class Splam::Rules::HiddenText < Splam::Rule
  ZERO_WIDTH_CHARS = [
    "\u200B",  # Zero-width space
    "\u200C",  # Zero-width non-joiner
    "\u200D",  # Zero-width joiner
    "\uFEFF",  # Zero-width no-break space
  ]

  def run
    ZERO_WIDTH_CHARS.each do |char|
      count = @body.count(char)
      if count > 0
        add_score count * 20, "Zero-width characters detected: #{count}"
      end
    end
  end
end
```

---

### 5. Performance Optimizations

#### A. Rule Execution Ordering

**Opportunity**: Run cheap rules first, expensive rules only if needed

```ruby
class Splam::Suite
  def run(record, request)
    # Sort rules by cost (cheap to expensive)
    ordered_rules = rules.sort_by { |rule_class, _| rule_class.cost }

    score = 0
    reasons = []

    ordered_rules.each do |rule_class, weight|
      # Early exit if already clearly spam
      break if score > threshold * 2

      worker = rule_class.run(self, record, weight, request)
      score += worker.score
      reasons << worker.reasons
    end

    [score, reasons]
  end
end

class Splam::Rule
  # Rules declare their computational cost
  def self.cost
    :cheap  # :cheap, :medium, :expensive
  end
end

class Splam::Rules::Httpbl
  def self.cost
    :expensive  # Network call
  end
end
```

---

#### B. Caching & Memoization

**Opportunity**: Cache expensive computations

```ruby
class Splam::Rule
  def initialize(suite, record, weight = 1.0, request = nil)
    @suite, @weight, @score, @reasons, @body, @request =
      suite, weight, 0, [], record.send(suite.body), request
    @user = record.user
    @cache = {}  # Instance-level cache
  end

  def tokens
    @cache[:tokens] ||= Splam::Ngram.tokenize(@body)
  end

  def trigrams
    @cache[:trigrams] ||= Splam::Ngram.trigram(@body)
  end

  def links
    @cache[:links] ||= @body.scan(/https?:\/\/[^\s<]+/)
  end
end

# Shared across rules in same suite execution
class Splam::Suite
  def run(record, request)
    @shared_cache = {}  # Suite-level cache
    # Pass cache to rules
  end
end
```

---

### 6. Deployment & Operations

#### A. A/B Testing Framework

```ruby
class Splam::ABTest
  def self.variant_for(user_id)
    # Deterministic assignment based on user_id
    variants = [:control, :bayesian, :tfidf]
    variants[user_id.hash % variants.size]
  end
end

class Comment
  def check_spam
    variant = Splam::ABTest.variant_for(user_id)

    case variant
    when :control
      # Current rule set
    when :bayesian
      # Bayesian-heavy ruleset
    when :tfidf
      # TF-IDF based ruleset
    end

    # Log results for analysis
    Splam::Metrics.log_variant_result(variant, self)
  end
end
```

---

#### B. Explainable AI

**Opportunity**: Better explain spam decisions to users

```ruby
class Splam::Explainer
  def self.explain(comment)
    reasons = comment.splam_reasons[:body]

    # Group by category
    grouped = {
      content: [],
      links: [],
      user: [],
      patterns: []
    }

    reasons.each do |reason|
      case reason
      when /bad_words|suspicious_word/
        grouped[:content] << reason
      when /href|link/
        grouped[:links] << reason
      when /user|email/
        grouped[:user] << reason
      else
        grouped[:patterns] << reason
      end
    end

    # Generate human-readable explanation
    explanation = []
    explanation << "Your post was flagged for the following reasons:"
    explanation << "- Content contains spam keywords" if grouped[:content].any?
    explanation << "- Multiple suspicious links detected" if grouped[:links].any?
    explanation << "- New user account" if grouped[:user].any?

    explanation.join("\n")
  end
end
```

---

## Priority Recommendations

### High Priority (Immediate Value)

1. **Bayesian Filter Enhancement** (Medium effort, High impact)
   - Infrastructure exists, just needs proper implementation
   - Would reduce maintenance significantly
   - Adapts to new spam automatically

2. **Score Normalization** (Low effort, High impact)
   - Makes system more predictable
   - Enables better ensemble methods
   - Foundation for other improvements

3. **Feedback Loop** (Medium effort, High impact)
   - Captures false positives/negatives
   - Enables continuous improvement
   - Critical for long-term success

### Medium Priority (Nice to Have)

4. **TF-IDF Features** (Medium effort, Medium impact)
   - More sophisticated than current binary matching
   - Reduces false positives

5. **Rule Performance Tracking** (Low effort, Medium impact)
   - Visibility into what's working
   - Data-driven optimization

6. **Modern Spam Patterns** (Low effort per rule, Cumulative impact)
   - Unicode obfuscation
   - Emoji spam
   - Zero-width characters

### Low Priority (Future Research)

7. **Deep Learning** (High effort, Unknown impact)
   - LSTM/Transformer models
   - Requires significant training data
   - May be overkill for current problem size

8. **Ensemble Meta-Classifier** (High effort, Medium impact)
   - Logistic regression on rule outputs
   - Best if you have lots of labeled data

## Conclusion

Splam has a solid foundation. The highest-value improvements focus on:
1. Making the existing ngram system actually useful (Bayesian filtering)
2. Adding feedback loops for continuous learning
3. Normalizing scores for better interpretability
4. Addressing modern obfuscation techniques

The beauty of the modular design means these can be added incrementally without disrupting the existing system.
