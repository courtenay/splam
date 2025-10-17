#!/usr/bin/env ruby
# frozen_string_literal: true

# Benchmark Bayesian classifier performance
# Demonstrates Ruby 3.x features: Ractors, pattern matching, hash shorthand

require 'benchmark'
require_relative '../lib/splam'
require_relative '../lib/splam/bayesian'

puts "=" * 70
puts "Splam Bayesian Classifier Benchmark"
puts "Ruby #{RUBY_VERSION} (#{RUBY_PLATFORM})"
puts "=" * 70
puts

# Load pre-trained classifier
cache_file = File.join(__dir__, '../test/fixtures/trained_classifier.dat')
if File.exist?(cache_file)
  puts "Loading pre-trained classifier..."
  classifier = Splam::Bayesian.load(cache_file)
else
  puts "Training classifier from fixtures..."
  classifier = Splam::Bayesian::BayesianTest.train_from_all_fixtures
end

stats = classifier.stats
puts "Classifier stats:"
puts "  Spam docs: #{stats[:spam_docs]}"
puts "  Ham docs: #{stats[:ham_docs]}"
puts "  Vocabulary: #{stats[:vocabulary_size]} trigrams"
puts "  Alpha (smoothing): #{stats[:alpha]}"
puts

# Generate test data
test_texts = [
  "buy cheap viagra pills online pharmacy discount medication",
  "I found a bug in the API and need help fixing it",
  "cheap cialis medication online pharmacy discount prices",
  "thanks for reviewing my code and providing feedback",
  "online pharmacy viagra cialis discount cheap pills",
  "could you help me understand this error message",
  "pharmaceutical discount medication cheap online",
  "I appreciate the detailed code review comments",
  "buy pills medication pharmacy online cheap discount",
  "let me know if you have questions about the implementation"
] * 10  # 100 texts total

puts "Test dataset: #{test_texts.size} documents"
puts

# Benchmark sequential classification
puts "Benchmarking sequential classification..."
sequential_time = Benchmark.realtime do
  test_texts.each { |text| classifier.classify(text) }
end
puts "  Time: #{(sequential_time * 1000).round(2)}ms"
puts "  Rate: #{(test_texts.size / sequential_time).round(1)} docs/sec"
puts

# Benchmark parallel classification (Ruby 3.0+)
if defined?(Ractor)
  puts "Benchmarking parallel classification (Ractors)..."

  [2, 4].each do |workers|
    parallel_time = Benchmark.realtime do
      classifier.classify_parallel(test_texts, workers: workers)
    end
    speedup = sequential_time / parallel_time
    puts "  Workers: #{workers}"
    puts "    Time: #{(parallel_time * 1000).round(2)}ms"
    puts "    Rate: #{(test_texts.size / parallel_time).round(1)} docs/sec"
    puts "    Speedup: #{speedup.round(2)}x"
    puts
  end
else
  puts "Ractors not available (Ruby < 3.0)"
  puts
end

# Demonstrate pattern matching (Ruby 3.0+)
puts "Demonstrating pattern matching..."
sample_results = test_texts.first(5).map { classifier.classify(_1) }

sample_results.each_with_index do |result, i|
  classification = case result
                  in { is_spam: true, confidence: 0.8.. }
                    "HIGH CONFIDENCE SPAM"
                  in { is_spam: true, confidence: 0.5..0.8 }
                    "MEDIUM CONFIDENCE SPAM"
                  in { is_spam: true }
                    "LOW CONFIDENCE SPAM"
                  in { is_spam: false, confidence: 0.8.. }
                    "HIGH CONFIDENCE HAM"
                  in { is_spam: false }
                    "HAM"
                  end

  puts "  Text #{i + 1}: #{classification} (p=#{result[:spam_probability].round(3)})"
end
puts

# Demonstrate numbered block parameters (Ruby 3.1+)
puts "Demonstrating numbered block parameters (_1, _2)..."
top_results = sample_results.sort_by { -_1[:confidence] }.first(3)
top_results.each_with_index { puts "  #{_2 + 1}. Confidence: #{_1[:confidence].round(3)}" }
puts

# Demonstrate hash shorthand (Ruby 3.1+)
puts "Demonstrating hash shorthand syntax..."
sample = sample_results.first
spam_probability = sample[:spam_probability]
confidence = sample[:confidence]
is_spam = sample[:is_spam]

summary = { spam_probability:, confidence:, is_spam: }
puts "  Summary: #{summary.inspect}"
puts

puts "=" * 70
puts "Benchmark complete!"
puts "=" * 70
