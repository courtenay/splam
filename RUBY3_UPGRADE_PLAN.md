# Ruby 3.x Upgrade Plan (v1.0.0)

## Overview

With Ruby 3.1.2 installed, we can modernize Splam to take advantage of modern Ruby features while maintaining v0.4.0 for legacy systems.

## Version Strategy

- **v0.4.x**: Ruby 2.2.3+ support (legacy)
- **v1.0.0**: Ruby 3.1+ support (modern)

## Ruby 3.x Features to Leverage

### 1. Improved Performance

Ruby 3.x is 3x faster than Ruby 2.0. Our Bayesian filter will benefit significantly.

**Current**:
```ruby
# Traditional iteration
trigrams.each do |trigram, count|
  # Process
end
```

**Modern**:
```ruby
# Ractor for parallel processing (Ruby 3.0+)
ractors = trigrams.each_slice(100).map do |chunk|
  Ractor.new(chunk) do |data|
    data.map { |trigram, count| process(trigram, count) }
  end
end

results = ractors.map(&:take).flatten
```

### 2. Pattern Matching

Ruby 3.0+ pattern matching for cleaner result handling:

**Current**:
```ruby
result = classifier.classify(text)
if result[:spam_probability] > 0.5
  # Handle spam
elsif result[:spam_probability] < 0.3
  # Handle ham
else
  # Handle uncertain
end
```

**Modern**:
```ruby
case classifier.classify(text)
in { spam_probability: prob, confidence: conf } if prob > 0.5 && conf > 0.7
  # High confidence spam
in { spam_probability: prob } if prob > 0.5
  # Probable spam
in { spam_probability: prob } if prob < 0.3
  # Probable ham
else
  # Uncertain
end
```

### 3. Endless Methods

Cleaner syntax for simple methods:

**Current**:
```ruby
def normalize_vector(vector)
  magnitude = Math.sqrt(vector.sum { |x| x ** 2 })
  return vector if magnitude.zero?
  vector.map { |x| x / magnitude }
end
```

**Modern**:
```ruby
def normalize_vector(vector) =
  (magnitude = Math.sqrt(vector.sum { |x| x ** 2 })).zero? ?
    vector :
    vector.map { |x| x / magnitude }
```

### 4. Numbered Block Parameters

Cleaner block syntax:

**Current**:
```ruby
spam_indicators.sort_by { |i| -i[:ratio] }.first(5)
```

**Modern**:
```ruby
spam_indicators.sort_by { -_1[:ratio] }.first(5)
```

### 5. Hash Shorthand (Ruby 3.1+)

**Current**:
```ruby
{
  spam_probability: spam_probability,
  ham_probability: ham_probability,
  confidence: confidence
}
```

**Modern**:
```ruby
{ spam_probability:, ham_probability:, confidence: }
```

### 6. Fiber Scheduler for Async I/O

For Redis operations:

**Current**:
```ruby
# Blocking Redis calls
trigrams.each do |trigram, count|
  @redis.hget(spam_key, trigram)
  @redis.hget(ham_key, trigram)
end
```

**Modern**:
```ruby
# Non-blocking with Fiber scheduler
require 'async'

Async do
  trigrams.map do |trigram, count|
    Async do
      [
        @redis.hget(spam_key, trigram),
        @redis.hget(ham_key, trigram)
      ]
    end
  end.map(&:wait)
end
```

### 7. Better Error Messages

Ruby 3 has much better error messages for debugging.

### 8. Type Signatures (RBS)

Add type checking:

**Create `sig/splam.rbs`**:
```rbs
module Splam
  class Bayesian
    def initialize: (?site_id: Integer?, ?storage: Storage?, ?alpha: Float) -> void
    def train: (String text, is_spam: bool, ?retrain: bool) -> void
    def classify: (String text) -> Hash[Symbol, untyped]
    def stats: () -> Hash[Symbol, untyped]
  end
end
```

## Modernization Checklist

### Code Quality

- [ ] Add type signatures (RBS)
- [ ] Use pattern matching where appropriate
- [ ] Leverage endless method definitions
- [ ] Use hash shorthand syntax
- [ ] Add numbered block parameters
- [ ] Remove workarounds for Ruby 2.x bugs

### Performance

- [ ] Implement Ractor-based parallel classification
- [ ] Use Fiber scheduler for Redis I/O
- [ ] Benchmark improvements vs v0.4.0
- [ ] Profile memory usage

### Testing

- [ ] Update test suite for Ruby 3.x
- [ ] Add performance benchmarks
- [ ] Test with RBS type checking
- [ ] Test Ractor implementation

### Dependencies

- [ ] Update ActiveSupport to 7.x
- [ ] Review all dependencies for Ruby 3.x compatibility
- [ ] Update development dependencies (RSpec, etc.)

### Documentation

- [ ] Update README for Ruby 3.x features
- [ ] Add migration guide from v0.4.x to v1.0.0
- [ ] Document performance improvements
- [ ] Add RBS documentation

## Implementation Plan

### Phase 1: Foundation (Week 1)

1. Update gemspec for Ruby 3.1+
2. Update dependencies to latest versions
3. Run test suite and fix deprecations
4. Add RBS type signatures

### Phase 2: Modernization (Week 2)

1. Refactor using pattern matching
2. Add endless method definitions
3. Use hash shorthand
4. Implement numbered block parameters

### Phase 3: Performance (Week 3)

1. Implement Ractor-based parallelization
2. Add Fiber scheduler for Redis
3. Benchmark improvements
4. Optimize hot paths

### Phase 4: Testing & Documentation (Week 4)

1. Comprehensive testing
2. Performance benchmarks
3. Migration guide
4. Release v1.0.0

## Breaking Changes

### Ruby Version

```ruby
# v0.4.0
s.required_ruby_version = ">= 2.2.3"

# v1.0.0
s.required_ruby_version = ">= 3.1.0"
```

### ActiveSupport

```ruby
# v0.4.0
s.add_runtime_dependency "activesupport", ">= 4.0"

# v1.0.0
s.add_runtime_dependency "activesupport", ">= 7.0"
```

### API Changes (Potential)

Consider making the API more modern:

**Current**:
```ruby
classifier.classify(text)
# => { spam_probability: 0.9, ... }
```

**Modern (with pattern matching)**:
```ruby
case classifier.classify(text)
in SpamResult[probability: > 0.7]
  # Handle
end
```

## Performance Targets

| Metric | v0.4.0 (Ruby 2.x) | v1.0.0 (Ruby 3.x) | Target Improvement |
|--------|-------------------|-------------------|-------------------|
| Classification | 10ms | 3ms | 3x faster |
| Training (1000 docs) | 5s | 2s | 2.5x faster |
| Memory (per doc) | 1KB | 700 bytes | 30% reduction |

## Backward Compatibility

v1.0.0 will NOT be backward compatible with Ruby < 3.1. Users on older Ruby versions should use v0.4.x.

## Migration Path

### For Users on Ruby 2.x

```ruby
# Stay on v0.4.x
gem 'splam', '~> 0.4.0'
```

### For Users on Ruby 3.x

```ruby
# Upgrade to v1.0.0
gem 'splam', '~> 1.0.0'

# No API changes, just performance improvements
# Code works the same way
```

## Example: Ractor-based Classification

```ruby
class Splam::Bayesian
  # Classify multiple documents in parallel
  def classify_batch(texts)
    # Split into chunks for parallel processing
    chunk_size = (texts.size / Ractor.available_cpus.to_f).ceil

    ractors = texts.each_slice(chunk_size).map do |chunk|
      Ractor.new(chunk, @storage, @site_id, @alpha) do |chunk, storage, site_id, alpha|
        classifier = Splam::Bayesian.new(
          storage: storage.dup,
          site_id: site_id,
          alpha: alpha
        )

        chunk.map { |text| classifier.classify(text) }
      end
    end

    # Collect results
    ractors.flat_map(&:take)
  end
end

# Usage
results = classifier.classify_batch(1000.times.map { "test text" })
# 10x faster on 10-core machine!
```

## Example: Pattern Matching

```ruby
class Splam::Rules::BayesianFilter
  def run
    case classifier.classify(@body)

    # High confidence spam
    in { spam_probability: prob, confidence: conf, spam_indicators: indicators }
       if prob > 0.7 && conf > 0.8
      score = 200
      top = indicators.first(3).map { _1[:trigram] }
      add_score score, "High confidence spam: #{top.join(', ')}"

    # Moderate confidence spam
    in { spam_probability: prob, confidence: conf } if prob > 0.5
      score = ((prob - 0.5) * 400).to_i
      add_score score, "Probable spam (#{(conf * 100).round}% confident)"

    # Probable ham
    in { spam_probability: prob } if prob < 0.3
      score = ((0.5 - prob) * 100).to_i
      add_score -score, "Probable ham"

    # Uncertain
    else
      add_score 0, "Uncertain"
    end
  end
end
```

## Next Steps

1. Wait for Ruby 3.1.2 installation to complete
2. Create branch `feature/ruby3-upgrade`
3. Implement Phase 1 (Foundation)
4. Tag as v1.0.0-beta1 for testing
5. Iterate and release v1.0.0

## Questions to Consider

1. Should we use Ractors for parallel processing?
2. Should we add RBS type signatures?
3. Should we use pattern matching extensively?
4. Should we maintain backward compatibility with Ruby 2.x in v1.0.0?
   - **Recommendation**: No, let v0.4.x handle legacy Ruby

## Resources

- [Ruby 3.0 Release Notes](https://www.ruby-lang.org/en/news/2020/12/25/ruby-3-0-0-released/)
- [Ruby 3.1 Release Notes](https://www.ruby-lang.org/en/news/2021/12/25/ruby-3-1-0-released/)
- [Pattern Matching Guide](https://docs.ruby-lang.org/en/3.0.0/doc/syntax/pattern_matching_rdoc.html)
- [Ractor Guide](https://docs.ruby-lang.org/en/3.0.0/doc/ractor_md.html)
- [RBS Documentation](https://github.com/ruby/rbs)

---

This upgrade will make Splam a modern, performant gem while maintaining legacy support in v0.4.x.
