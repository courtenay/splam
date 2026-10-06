source 'https://rubygems.org'
gemspec

old = RUBY_VERSION < '2.3' # Tender runs 2.2

# the newest versions that still run on old Rubies (Bundler 1.x ignores required_ruby_version)
gem 'rake', (old ? '< 13' : '>= 0')
gem 'test-unit', (old ? '< 3.3' : '>= 0')
gem 'power_assert', '< 1.1' if old
gem 'redis', (old ? '< 4.0' : '>= 0') # optional, for test/ngram_test.rb
gem 'public_suffix', '< 3.0' if old
