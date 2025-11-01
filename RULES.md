# Splam Detection Rules

This document provides detailed information about each spam detection rule included in Splam.

## Table of Contents

- [Overview](#overview)
- [Content Analysis Rules](#content-analysis-rules)
- [Link Analysis Rules](#link-analysis-rules)
- [Language Detection Rules](#language-detection-rules)
- [User Analysis Rules](#user-analysis-rules)
- [Network Analysis Rules](#network-analysis-rules)
- [Scoring Weights](#scoring-weights)
- [Creating Custom Rules](#creating-custom-rules)

## Overview

Splam uses a modular rule-based system where each rule examines content and contributes points to an overall spam score. Rules can add positive points (spam indicators) or negative points (legitimate content indicators).

### Rule Execution

All rules inherit from `Splam::Rule` and implement a `run` method that:
1. Analyzes the content (`@body`)
2. Optionally checks user information (`@user`)
3. Optionally checks request data (`@request`)
4. Calls `add_score(points, reason)` to contribute to the spam score

### Default Rules

By default, all rule subclasses are automatically included. You can customize this:

```ruby
# Use only specific rules
splammable :body do |suite|
  suite.rules = [:bad_words, :href, :punctuation]
end

# Adjust weights
splammable :body do |suite|
  suite.rules = {
    Splam::Rules::BadWords => 2.0,  # Double impact
    Splam::Rules::Href => 0.5        # Half impact
  }
end
```

## Content Analysis Rules

### BadWords

**File:** `lib/splam/rules/bad_words.rb`

**Purpose:** Detects spam-related keywords and phrases across multiple categories.

**Categories:**
- **Porn spam**: Adult content keywords, torrent, webcam
- **Pharmaceutical spam**: viagra, cialis, xanax, propecia
- **Scam keywords**: payday loans, Nigerian prince patterns, lottery wins
- **Tech support scams**: Support phone numbers, "call now" patterns
- **E-commerce spam**: Counterfeit goods, handbags, watches, shoes
- **Diet/supplement spam**: Weight loss, keto, muscle building
- **Voodoo/astrology spam**: Love spells, astrologer, vashikaran
- **Link building spam**: "increase traffic", backlinks, SEO

**Scoring:**
- `bad_word_score`: 15 points per match (default)
- `suspicious_word_score`: 4 points per match (default)
- Multipliers applied for repeated words
- Extra penalties if bad words appear inside HTML links
- 50 points bonus if multiple words from same category

**Configuration:**
```ruby
# Adjust scoring weights
Splam::Rules::BadWords.bad_word_score = 20
Splam::Rules::BadWords.suspicious_word_score = 5
```

**Example detections:**
- "Buy viagra cheap" → ~45 points
- "Call girl escorts +971-557-928-406" → 150+ points
- "Male enhancement supplements" → 60+ points

---

### BBCode

**File:** `lib/splam/rules/bbcode.rb`

**Purpose:** Detects BBCode formatting commonly used by forum spammers.

**Patterns detected:**
- `[url=...]` tags
- `[IMG]` tags
- `[CODE]` tags
- `[b]`, `[a]`, `[i]` tags

**Scoring:**
- 40 points per `[url=` or `[IMG` tag
- 80 points for URL covering entire line
- 45 points for `[url=http` (malformed BBCode)
- 30 points for `[/CODE]` tags
- 10 points per formatting tag

**Why effective:** Forum spammers often copy-paste BBCode between sites. Legitimate users of issue trackers rarely use BBCode.

---

### Punctuation

**File:** `lib/splam/rules/punctuation.rb`

**Purpose:** Analyzes sentence structure and punctuation patterns.

**Checks:**
- Missing punctuation (10 points)
- Sentences longer than 30 words (10 points per sentence)
- Sentences longer than 10 words (1 point per sentence)

**Special handling:**
- Skips technical content (stack traces, file paths, hex addresses)
- Uses `line_safe?()` to avoid false positives

**Why effective:** Spam often lacks proper punctuation or uses run-on sentences.

---

### Fuzz

**File:** `lib/splam/rules/fuzz.rb`

**Purpose:** Detects repeated characters often used for emphasis in spam.

**Patterns:**
- 3+ repeated letters: "hellooooo" (5 points)
- 4+ repeated letters: 50 points
- 2+ repeated punctuation: "!!!" or "???" (10 points)
- 4+ repeated punctuation: 50 points

**Why effective:** Spam often uses excessive punctuation or repeated letters for attention.

---

### LineLength

**File:** `lib/splam/rules/line_length.rb`

**Purpose:** Detects abnormally long lines of text.

**Scoring:**
- Lines over 300 characters: 20 points per line
- Lines over 400 characters: 50 points per line

**Special handling:**
- Ignores technical content (stack traces, file paths)

---

### WordLength

**File:** `lib/splam/rules/word_length.rb`

**Purpose:** Detects suspicious word patterns.

**Checks:**
- Words with 3+ consecutive repeated characters: "freeee" (5 points)
- Words with 4+ consecutive repeated characters (50 points)

---

### TokenUniqueness

**File:** `lib/splam/rules/token_uniqueness.rb`

**Purpose:** Measures content diversity.

**Scoring:**
- Low token diversity suggests copy-paste spam
- Compares unique words to total word count

---

## Link Analysis Rules

### Href

**File:** `lib/splam/rules/href.rb`

**Purpose:** Comprehensive link analysis and suspicious URL detection.

**Checks:**

1. **Link count:**
   - 1 point per `http://` or `https://`
   - 50 points if more than 3 links
   - 100 points if more than 5 links
   - 1000 points if more than 10 links

2. **Link formatting:**
   - 50 points for `href=http` (malformed HTML)
   - 35 points for `href=" http` (extra space)
   - 50 points for single link posts
   - 50 points for posts ending with link

3. **Suspicious TLDs:**
   - `.ru` (Russian): 20 points
   - `.cn` (Chinese): 20 points
   - `.xyz`: 50 points
   - `.top`, `.download`, `.stream`: 50-80 points
   - `.info`, `.tk`, `.eu`: 20 points
   - `.biz`: 40 points

4. **Suspicious domains:**
   - `cnn`, `bbc`, `ask`: 10 points each
   - `blogspot`, `kinja`, `issuu`: 30 points
   - `youtube`, `wordpress`: 20 points

5. **Link patterns:**
   - Links with no path: 15 points
   - Unparseable URIs: 25 points
   - Duplicate links: 50 points
   - Text ending in link token: 10-50 points

**Why effective:** Spammers rely heavily on links. Multiple links, suspicious TLDs, and malformed HTML are strong spam indicators.

---

### Html

**File:** `lib/splam/rules/html.rb`

**Purpose:** Detects excessive or suspicious HTML.

**Checks:**
- Raw HTML tags in content
- Excessive formatting
- Hidden content techniques

---

### Assets

**File:** `lib/splam/rules/assets.rb`

**Purpose:** Detects suspicious asset file references.

**Patterns:**
- Unusual file extensions
- Suspicious download links
- Asset hosting patterns common in spam

---

## Language Detection Rules

### Russian

**File:** `lib/splam/rules/russian.rb`

**Purpose:** Detects Cyrillic characters often found in Russian spam.

**Scoring:**
- 3 points per Cyrillic character detected
- Checks for specific Russian letters: С, А, М, Я, Л, У, etc.

**Why effective:** Unexpected Russian text in English content is often spam.

**Configuration:**
```ruby
# Reduce impact for multilingual sites
splammable :body do |suite|
  suite.rules = {Splam::Rules::Russian => 0.2}
end
```

---

### Chinese

**File:** `lib/splam/rules/chinese.rb`

**Purpose:** Detects Chinese characters (Simplified and Traditional).

**Scoring:**
- Checks for CJK (Chinese, Japanese, Korean) Unicode ranges
- Points assigned based on character frequency

**Why effective:** Chinese spam was common in the late 2000s/early 2010s.

---

### Korean

**File:** `lib/splam/rules/korean.rb`

**Purpose:** Detects Korean Hangul characters.

**Scoring:**
- Similar to Chinese/Russian detection
- Points for Hangul Unicode characters

---

## User Analysis Rules

### User

**File:** `lib/splam/rules/user.rb`

**Purpose:** Validates user attributes for suspicious patterns.

**Checks:**

1. **Username validation:**
   - Contains HTML tags: 250 points
   - Ends with `>`: 250 points

2. **Email validation:**
   - Suspicious domains: 50 points
     - `qq.com`, `yahoo.cn`, `126.com`
     - Keywords: `mortgage`, `keto`
   - More than 5 dots before @: 20 points

3. **User reputation:**
   - Untrusted users: 5 points
   - New accounts: higher scores (implement custom)

**Usage:**
```ruby
class User
  attr_accessor :name, :email

  def trusted?
    # Your trust logic
    verified_email? && created_at < 7.days.ago
  end
end
```

---

## Network Analysis Rules

### Httpbl

**File:** `lib/splam/rules/httpbl.rb`

**Purpose:** Checks IP addresses against Project Honeypot's HTTP:BL blacklist.

**Setup:**
```ruby
# Get API key from projecthoneypot.org
Splam::Rules::Httpbl.api_key = "your-api-key"

class Comment
  include Splam

  splammable :body do |suite|
    suite.request = lambda { |comment|
      { remote_ip: comment.ip_address }
    }
  end
end
```

**Scoring:**
- 250 points if IP appears in blacklist
- Checks both HTTP:BL and optional Redis cache
- DNS query with 0.5 second timeout

**Response details:**
- Days since last activity
- Threat score (0-255)
- Visitor type flags

**Why effective:** Project Honeypot tracks known spam IPs across the web.

---

### GeoIP

**File:** `lib/splam/rules/geoip.rb`

**Purpose:** Geographic IP analysis (requires GeoIP database).

**Potential checks:**
- Unexpected geographic sources
- VPN/proxy detection
- High-risk countries

---

## Special Rules

### True

**File:** `lib/splam/rules/true.rb`

**Purpose:** Honeypot field detection.

**How it works:**
1. Add a hidden field to your form (e.g., `honeypot`)
2. Legitimate users won't fill it (hidden via CSS)
3. Spam bots fill all fields automatically

**Setup:**
```html
<!-- In your form -->
<input type="text" name="website" style="display:none" />
```

```ruby
class Comment
  include Splam

  attr_accessor :body, :honeypot_field

  splammable :body do |suite|
    suite.rules = [Splam::Rules::True]
    suite.request = lambda { |comment|
      { counter: comment.honeypot_field, time: 5 }
    }
  end
end
```

**Scoring:**
- 300 points if honeypot field is filled
- Can also check time-to-submit (too fast = bot)

---

### GoodWords

**File:** `lib/splam/rules/good_words.rb`

**Purpose:** Reduces spam score for legitimate keywords.

**Patterns:**
- Technical terms: "API", "error", "bug", "feature"
- Polite language: "thank you", "thanks", "please"
- Development terms: "pull request", "commit", "test"

**Scoring:**
- Negative points (reduces spam score)
- Helps prevent false positives

---

### ArmsRace

**File:** `lib/splam/rules/arms_race.rb`

**Purpose:** Adapts to evolving spam patterns.

**Strategy:**
- Detects new spam techniques
- Pattern learning from recent spam
- Requires manual updates as spam evolves

---

## Scoring Weights

### Default Weights

| Points | Severity | Description |
|--------|----------|-------------|
| 1-5    | Very Low | Weak spam indicator |
| 5-15   | Low      | Minor suspicious pattern |
| 15-50  | Medium   | Moderate spam indicator |
| 50-100 | High     | Strong spam indicator |
| 100-250| Very High| Almost certain spam |
| 250+   | Critical | Definite spam (blacklisted) |

### Threshold Guidelines

| Threshold | Use Case |
|-----------|----------|
| 40-60     | Very aggressive (high false positives) |
| 80-120    | Aggressive (moderate false positives) |
| 120-180   | Balanced (recommended for most sites) |
| 180-250   | Conservative (fewer false positives) |
| 250+      | Very conservative (only obvious spam) |

### Typical Spam Scores

- **Obvious spam**: 500-5000 points
- **Clear spam**: 200-500 points
- **Probable spam**: 100-200 points
- **Suspicious**: 50-100 points
- **Borderline**: 30-50 points
- **Legitimate**: 0-30 points

## Creating Custom Rules

### Basic Template

```ruby
class Splam::Rules::MyRule < Splam::Rule
  def run
    # Access content
    text = @body

    # Access user (if available)
    user = @user

    # Access request data (if provided)
    ip = @request[:remote_ip] if @request

    # Add spam points
    add_score 10, "Reason for points"

    # Subtract spam points (for legitimate indicators)
    add_score -5, "Legitimate pattern detected"
  end
end
```

### Helper Methods

**`add_score(points, reason)`**
- Adds to spam score
- Records reason for debugging
- Automatically applies rule weight
- Caps scores to prevent overflow

**`line_safe?(string)`**
- Returns `true` if string looks like technical content
- Checks for: file paths, hex addresses, library paths
- Use to avoid false positives on stack traces

### Advanced Example

```ruby
class Splam::Rules::RateLimit < Splam::Rule
  # Class-level configuration
  class << self
    attr_accessor :redis_client, :window_seconds, :max_posts
  end

  self.window_seconds = 3600  # 1 hour
  self.max_posts = 10

  def run
    return unless @user && @user.respond_to?(:id)
    return unless self.class.redis_client

    key = "spam:rate_limit:#{@user.id}"
    count = self.class.redis_client.incr(key)
    self.class.redis_client.expire(key, self.class.window_seconds)

    if count > self.class.max_posts
      excess = count - self.class.max_posts
      add_score 20 * excess, "Posting too frequently: #{count} posts"
    elsif count > (self.class.max_posts * 0.7)
      add_score 5, "Elevated posting rate"
    end
  end
end

# Configure
Splam::Rules::RateLimit.redis_client = Redis.new
Splam::Rules::RateLimit.max_posts = 5

# Use
class Comment
  include Splam

  splammable :body do |suite|
    suite.rules << Splam::Rules::RateLimit
  end
end
```

### Testing Custom Rules

```ruby
# test/splam/rules/my_rule_test.rb
require 'test_helper'

class Splam::Rules::MyRuleTest < Test::Unit::TestCase
  def test_detects_pattern
    suite = Splam::Suite.new(:body, [Splam::Rules::MyRule], 100, nil)
    record = OpenStruct.new(body: "suspicious content")

    score, reasons = suite.run(record, nil)

    assert score > 0
    assert reasons.flatten.any? { |r| r.include?("my pattern") }
  end
end
```

## Best Practices

1. **Start conservative**: Use higher thresholds initially
2. **Monitor false positives**: Log all spam detections
3. **Combine signals**: Use Splam with other anti-spam measures
4. **Whitelist trusted users**: Skip checks for verified users
5. **Test with real data**: Use actual spam and ham in your tests
6. **Update regularly**: Spam evolves; update rules periodically
7. **Use weights**: Adjust rule weights for your specific use case
8. **Provide feedback**: Let users report false positives

## Debugging

### View Spam Reasons

```ruby
comment.splam_reasons[:body].each do |reason|
  puts reason
end

# Example output:
# bad_words: [15] nasty word (1x): 'viagra'
# href: [50] More than 3 links
# punctuation: [10] Text has no punctuation
```

### Analyze Scores Per Rule

```ruby
# Run rules individually to debug
Splam::Rule.default_rules.each do |rule_class|
  suite = Splam::Suite.new(:body, [rule_class], 0, nil)
  score, reasons = suite.run(comment, nil)

  if score > 0
    puts "#{rule_class.splam_key}: #{score} points"
    puts "  #{reasons.join("\n  ")}"
  end
end
```

### Test Against Fixtures

The gem includes 48 spam examples and 28 ham examples in `test/fixtures/comment/` for testing and tuning.

---

For more information, see the main [README.md](README.md) and [EXAMPLES.md](EXAMPLES.md).
