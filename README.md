# Splam

**A lightweight, rule-based spam detection library for Ruby**

Splam is a modular spam scoring system designed to help you detect spam in user-generated content like comments, forum posts, and messages. Rather than making binary spam/ham decisions, Splam assigns a numerical score based on various heuristic rules, letting you decide the appropriate threshold for your application.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features

- **Rule-based scoring system** - Each detection rule contributes points to an overall spam score
- **Highly customizable** - Choose which rules to apply and adjust their weights
- **Extensible architecture** - Easily add your own custom spam detection rules
- **Multiple detection strategies** including:
  - Bad word detection (porn, pharmaceuticals, scams, etc.)
  - BBCode and HTML link analysis
  - URL pattern matching with suspicious TLD detection
  - Excessive punctuation and formatting analysis
  - Non-Latin character detection (Russian, Chinese, Korean)
  - Project Honeypot IP blacklist integration
  - User validation (email patterns, name validation)
  - N-gram based trigram analysis (optional Bayesian-style filtering)
- **Battle-tested** - Used in production on Lighthouse (issue tracking platform)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'splam'
```

Or install it yourself:

```bash
gem install splam
```

## Quick Start

```ruby
class Comment
  include Splam

  # Mark the :body attribute as splammable with default threshold of 100
  splammable :body

  attr_accessor :body
end

comment = Comment.new
comment.body = "Buy cheap viagra now! Click here!!!"

comment.splam?        # => true
comment.splam_score   # => 250
comment.splam_reasons # => Array of scoring reasons
```

## Usage

### Basic Configuration

Include the `Splam` module in your model and declare which attributes should be checked:

```ruby
class Message
  include Splam

  # Default threshold: 100
  splammable :body

  attr_accessor :body
end
```

### Custom Threshold

Set a custom spam threshold for your specific use case:

```ruby
class Comment
  include Splam

  # Lower threshold = more aggressive spam detection
  splammable :body, 50

  attr_accessor :body
end
```

### Advanced Configuration

Use a block for fine-grained control over rules, thresholds, and conditions:

```ruby
class Post
  include Splam

  splammable :body do |suite|
    suite.threshold = 150

    # Only run specific rules
    suite.rules = [:chinese, :href, :bad_words]

    # Or use rule classes directly
    suite.rules = [Splam::Rules::Chinese, Splam::Rules::Href]

    # Apply custom weights to rules
    suite.rules = {
      Splam::Rules::BadWords => 2.0,  # Double the score
      :href => 0.5                     # Halve the score
    }

    # Skip spam check conditionally
    suite.conditions = lambda { |record| !record.author.trusted? }
  end
end
```

### Multiple Splammable Fields

You can check multiple fields in the same model:

```ruby
class BlogPost
  include Splam

  splammable :title, 80
  splammable :body, 120

  attr_accessor :title, :body
end

post = BlogPost.new
post.title = "Free money!!!"
post.body = "Legitimate content here"

post.splam?(:title)  # => true
post.splam?(:body)   # => false
post.splam?          # => true (any field over threshold)
```

### Checking Results

```ruby
comment = Comment.new
comment.body = "This looks like spam with viagra and cialis"

# Boolean spam check
comment.splam?  # => true or false based on threshold

# Get the numerical score
comment.splam_score  # => 245

# Get detailed scoring breakdown
comment.splam_reasons
# => {
#   :body => [
#     "bad_words: [15] nasty word (1x): 'viagra'",
#     "bad_words: [15] nasty word (1x): 'cialis'",
#     ...
#   ]
# }

# Get scores per field
comment.splam_scores  # => {:body => 245}
```

### Skip Spam Check

You can skip spam checking on specific records:

```ruby
comment.skip_splam_check = true
comment.splam?  # => false (check skipped)
```

## Built-in Detection Rules

Splam includes 18+ spam detection rules:

| Rule | Description | Key Indicators |
|------|-------------|----------------|
| **BadWords** | Detects spam keywords | Porn, pharmaceuticals, scams, tech support spam, etc. |
| **Bbcode** | BBCode link detection | `[url=]`, `[IMG]` tags |
| **Href** | HTML link analysis | Multiple links, suspicious TLDs (.ru, .cn, .xyz, etc.) |
| **Html** | HTML tag patterns | Excessive formatting tags |
| **Httpbl** | Project Honeypot integration | IP reputation checking (requires API key) |
| **Chinese** | Chinese character detection | Identifies Chinese text patterns |
| **Russian** | Cyrillic character detection | Identifies Russian text |
| **Korean** | Korean character detection | Identifies Korean text |
| **Punctuation** | Punctuation analysis | Missing punctuation, overly long sentences |
| **User** | User validation | Suspicious usernames, email patterns |
| **LineLength** | Line length analysis | Abnormally long lines |
| **WordLength** | Word length patterns | Repeated characters, suspicious patterns |
| **TokenUniqueness** | Repetition detection | Duplicate content |
| **Fuzz** | Character repetition | `!!!!!!`, `??????` |
| **GoodWords** | Negative scoring | Reduces score for legitimate keywords |
| **ArmsRace** | Pattern detection | Evolving spam patterns |
| **Assets** | Asset link detection | Suspicious file references |
| **True** | Honeypot detection | Hidden form field analysis |

## Writing Custom Rules

Extend Splam with your own spam detection logic:

```ruby
class Splam::Rules::CustomRule < Splam::Rule
  def run
    # Access the content being checked
    text = @body

    # Access the associated user (if available)
    user = @user

    # Add points for spam indicators
    add_score 10, "Contains 'urgent'" if text =~ /urgent/i
    add_score 25, "New user" if user && user.created_at > 1.day.ago

    # Subtract points for legitimate content
    add_score -5, "Contains code block" if text =~ /```/
  end
end
```

The `add_score(points, reason)` method:
- Adds to the spam score (use negative values to reduce score)
- Records the reason for debugging
- Applies the rule's weight automatically
- Caps individual scores to prevent integer overflow

## Project Honeypot Integration

To use HTTP:BL (HTTP Blacklist) for IP reputation checking:

```ruby
# Configure your API key (get one from projecthoneypot.org)
Splam::Rules::Httpbl.api_key = "your-api-key-here"

# Your model needs to provide request information
class Comment
  include Splam

  splammable :body do |suite|
    suite.request = lambda { |record|
      { remote_ip: record.ip_address }
    }
  end

  attr_accessor :body, :ip_address
end
```

## N-gram (Trigram) Analysis

Splam includes optional Bayesian-style spam detection using trigram analysis. This requires Redis:

```ruby
# Train the system with known spam and ham
corpus = Splam::Ngram.new(site_id)

# Train with legitimate content
corpus.train("This is a normal comment", false)

# Train with spam
corpus.train("Buy viagra cheap!!!", true)

# Compare new content
score, spam = corpus.compare("New comment text")
# Returns [ham_score, spam_score]
```

## Recommended Integration

### Soft Delete / Hidden Spam

Rather than rejecting spam outright, consider a "soft delete" approach:

```ruby
class Comment < ActiveRecord::Base
  include Splam

  splammable :body, 100

  before_save :check_spam

  def check_spam
    if splam? && !user.trusted?
      self.hidden = true
      self.spam_score = splam_score
    end
  end
end
```

This allows you to:
- Show the comment to the author (preventing re-posting)
- Hide it from other users
- Review borderline cases manually
- Build a corpus for training

### Adaptive Thresholds

Adjust spam thresholds based on user reputation:

```ruby
class Comment
  include Splam

  splammable :body do |suite|
    suite.threshold = 150
    suite.conditions = lambda { |record|
      # Skip check for trusted users
      return false if record.user.trusted?

      # Lower threshold for new users
      suite.threshold = 80 if record.user.created_at > 7.days.ago

      true
    }
  end
end
```

### Combining Signals

Use Splam scores alongside other spam signals:

```ruby
def likely_spam?
  score = splam_score

  # Adjust based on other factors
  score += 50 if user.created_at < 5.minutes.ago  # Very new user
  score += 30 if posted_too_quickly?               # Rapid posting
  score -= 20 if user.verified_email?              # Email verified
  score -= 40 if user.has_previous_activity?       # Active user

  score > 100
end
```

## Understanding Scores

Splam uses additive scoring where each rule contributes points:

- **0-40**: Probably legitimate content
- **40-100**: Borderline, may warrant review
- **100-500**: Likely spam
- **500+**: Almost certainly spam (some spam scores 1000+)

Individual rules can contribute different amounts:
- Small penalties (1-5 points): Weak signals
- Medium penalties (10-50 points): Moderate suspicion
- Large penalties (50-250 points): Strong spam indicators
- Critical penalties (250+): Near-certain spam (e.g., blacklisted IP)

## Configuration Tips

1. **Start conservative**: Begin with a higher threshold (150-200) and lower it based on false positives
2. **Monitor scores**: Log spam scores for legitimate content to tune thresholds
3. **Whitelist trusted users**: Skip checks for verified, long-standing users
4. **Combine approaches**: Use Splam with rate limiting, CAPTCHAs, and email verification
5. **Build a corpus**: Save spam/ham examples to improve detection rules

## Testing

Run the test suite:

```bash
bundle install
rake test
```

The gem includes extensive test fixtures with real-world spam and ham (legitimate content) examples.

## Development

The project structure:

```
lib/
├── splam.rb              # Main module and Suite class
├── splam/
│   ├── rule.rb           # Base Rule class
│   ├── rules.rb          # Rules module
│   ├── ngram.rb          # Trigram analysis
│   └── rules/            # Individual detection rules
│       ├── bad_words.rb
│       ├── bbcode.rb
│       ├── href.rb
│       └── ...
test/
├── fixtures/
│   └── comment/
│       ├── spam/         # Real spam examples
│       └── ham/          # Legitimate content
└── splam_test.rb
```

## Performance Considerations

- Most rules are simple regex matching - very fast
- The `Httpbl` rule makes DNS queries - can add latency
- N-gram analysis requires Redis - adds complexity
- Consider running checks asynchronously for high-traffic sites
- Cache spam scores if content doesn't change

## Limitations

- **Heuristic-based**: Not machine learning; won't adapt automatically
- **Language-specific**: Rules are tuned for English with some support for Russian/Chinese
- **Evolving spam**: May need updates as spam tactics change
- **No learning**: Unlike Bayesian filters, rules don't automatically improve from feedback

## Upgrading and Customization

Splam was designed for extensibility:

```ruby
# Disable specific rules globally
Splam::Rule.default_rules.delete(Splam::Rules::Punctuation)

# Adjust rule scoring
Splam::Rules::BadWords.bad_word_score = 20  # Default: 15

# Add site-specific bad words
# Edit lib/splam/rules/bad_words.rb or create a custom rule
```

## History

Splam was created by ENTP for the Lighthouse bug tracking application. It has been battle-tested against real-world spam since 2008 and has been continuously updated with new spam patterns.

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Add tests for your changes
4. Ensure all tests pass (`rake test`)
5. Commit your changes (`git commit -am 'Add some feature'`)
6. Push to the branch (`git push origin my-new-feature`)
7. Create a Pull Request

## License

Released under the MIT License. See [MIT-LICENSE](MIT-LICENSE) for details.

## Credits

Created by [ENTP](https://entp.com)

Maintained by Courtenay (courtenay@entp.com)

## Support

- GitHub Issues: [https://github.com/courtenay/splam/issues](https://github.com/courtenay/splam/issues)
- Source Code: [https://github.com/courtenay/splam](https://github.com/courtenay/splam)
