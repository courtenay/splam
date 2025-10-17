# Splam Usage Examples

This document provides practical examples of using Splam in various scenarios.

## Table of Contents

- [Basic Integration](#basic-integration)
- [Rails Integration](#rails-integration)
- [Sinatra Integration](#sinatra-integration)
- [Custom Rules](#custom-rules)
- [Advanced Configurations](#advanced-configurations)
- [Testing](#testing)

## Basic Integration

### Simple Comment Model

```ruby
class Comment
  include Splam

  splammable :body

  attr_accessor :body, :author

  def user
    author
  end
end

# Usage
comment = Comment.new
comment.body = "Buy cheap viagra now!!!"
comment.splam?        # => true
comment.splam_score   # => 350
```

### With User Context

```ruby
class User
  attr_accessor :name, :email, :created_at, :trusted

  def trusted?
    @trusted || false
  end
end

class Comment
  include Splam

  splammable :body, 100

  attr_accessor :body, :user
end

# New user posting suspicious content
new_user = User.new
new_user.created_at = Time.now
new_user.trusted = false

comment = Comment.new
comment.body = "Check out my website http://suspicious-site.xyz"
comment.user = new_user

comment.splam?  # => true
comment.splam_score  # => 150
```

## Rails Integration

### ActiveRecord Model

```ruby
class Comment < ActiveRecord::Base
  include Splam

  belongs_to :user
  belongs_to :post

  # Mark body as splammable with threshold of 100
  splammable :body, 100

  # Automatically check spam before saving
  before_validation :check_spam, on: :create

  # Validation
  validate :not_obvious_spam, on: :create

  private

  def check_spam
    # Store the spam score for analysis
    self.spam_score = splam_score

    # Auto-hide if spam score is very high
    if splam_score > 200 && !user.trusted?
      self.hidden = true
      self.spam_reason = splam_reasons[:body].join("; ")
    end
  end

  def not_obvious_spam
    if splam? && splam_score > 500
      errors.add(:body, "appears to be spam. Please try again.")
    end
  end
end
```

### Controller with Request Context

```ruby
class CommentsController < ApplicationController
  def create
    @comment = Comment.new(comment_params)
    @comment.user = current_user
    @comment.ip_address = request.remote_ip

    if @comment.splam? && @comment.splam_score > 300
      # Log suspicious activity
      Rails.logger.warn "High spam score: #{@comment.splam_score} from IP #{request.remote_ip}"

      # Show comment to user but hide from others
      @comment.visible_to_author_only = true
    end

    if @comment.save
      redirect_to @comment.post, notice: "Comment posted."
    else
      render :new
    end
  end

  private

  def comment_params
    params.require(:comment).permit(:body)
  end
end
```

### Admin Interface

```ruby
# app/admin/comments.rb (ActiveAdmin example)
ActiveAdmin.register Comment do
  scope :all
  scope :suspected_spam, -> { where("spam_score > ?", 100) }
  scope :hidden, -> { where(hidden: true) }

  index do
    column :id
    column :user
    column :spam_score do |comment|
      status_tag(
        comment.spam_score,
        comment.spam_score > 200 ? :error :
        comment.spam_score > 100 ? :warning : :ok
      )
    end
    column :body do |comment|
      truncate(comment.body, length: 100)
    end
    column :created_at

    actions defaults: true do |comment|
      link_to "Mark Ham", mark_ham_admin_comment_path(comment), method: :post if comment.hidden
      link_to "Mark Spam", mark_spam_admin_comment_path(comment), method: :post unless comment.hidden
    end
  end

  member_action :mark_ham, method: :post do
    resource.update(hidden: false, spam_score: 0)
    redirect_to admin_comments_path, notice: "Marked as ham"
  end

  member_action :mark_spam, method: :post do
    resource.update(hidden: true)
    redirect_to admin_comments_path, notice: "Marked as spam"
  end
end
```

### Background Job Processing

```ruby
# app/jobs/spam_check_job.rb
class SpamCheckJob < ApplicationJob
  queue_as :default

  def perform(comment_id)
    comment = Comment.find(comment_id)

    if comment.splam? && comment.splam_score > 150
      comment.update(
        hidden: true,
        spam_score: comment.splam_score,
        spam_details: comment.splam_reasons.to_json
      )

      # Notify moderators if score is very high
      if comment.splam_score > 500
        ModerationMailer.high_spam_alert(comment).deliver_later
      end
    end
  end
end

# In your controller
@comment.save
SpamCheckJob.perform_later(@comment.id)
```

## Sinatra Integration

```ruby
require 'sinatra'
require 'splam'

class BlogComment
  include Splam

  splammable :body, 120

  attr_accessor :body, :author_name, :author_email, :user

  def save
    # Your save logic here
  end
end

post '/comments' do
  comment = BlogComment.new
  comment.body = params[:body]
  comment.author_name = params[:name]
  comment.author_email = params[:email]

  # Create a simple user object for Splam rules
  user = OpenStruct.new(
    name: params[:name],
    email: params[:email],
    trusted?: false
  )
  comment.user = user

  if comment.splam?
    # Log spam attempt
    logger.warn "Spam detected: score=#{comment.splam_score}, reasons=#{comment.splam_reasons}"

    # Show message to user but don't save
    halt 422, "Your comment was flagged as spam. Please contact us if this is an error."
  end

  comment.save
  redirect '/comments'
end
```

## Custom Rules

### Domain-Specific Rule

```ruby
class Splam::Rules::TechSupport < Splam::Rule
  def run
    # Detect tech support scams
    support_patterns = [
      /call.*(?:now|today|immediately)/i,
      /toll[- ]free/i,
      /customer (?:support|service|care)/i,
      /\d{3}[-.\s]\d{3}[-.\s]\d{4}/,  # Phone numbers
      /support.*number/i
    ]

    support_patterns.each do |pattern|
      matches = @body.scan(pattern).size
      if matches > 0
        add_score 50 * matches, "Tech support scam pattern: #{pattern}"
      end
    end

    # Multiple phone numbers = very suspicious
    phone_count = @body.scan(/\d{3}[-.\s]\d{3}[-.\s]\d{4}/).size
    if phone_count > 2
      add_score 200, "Multiple phone numbers (#{phone_count})"
    end
  end
end
```

### Content-Specific Rule

```ruby
class Splam::Rules::PromotionalLinks < Splam::Rule
  def run
    # Detect promotional link patterns
    promo_keywords = [
      'discount', 'coupon', 'sale', 'clearance',
      'limited time', 'order now', 'click here'
    ]

    # Count promotional keywords
    promo_count = 0
    promo_keywords.each do |keyword|
      count = @body.downcase.scan(keyword).size
      promo_count += count
      add_score 5 * count, "Promotional keyword: #{keyword}" if count > 0
    end

    # Extra penalty if promotional keywords appear with links
    link_count = @body.scan(/https?:\/\//).size
    if promo_count > 0 && link_count > 0
      add_score 30 * [promo_count, link_count].min, "Promotional content with links"
    end
  end
end
```

### User Reputation Rule

```ruby
class Splam::Rules::Reputation < Splam::Rule
  def run
    return unless @user

    # Reduce score for trusted users
    add_score -50, "Trusted user" if @user.respond_to?(:trusted?) && @user.trusted?

    # Increase score for very new accounts
    if @user.respond_to?(:created_at)
      account_age_hours = (Time.now - @user.created_at) / 3600

      if account_age_hours < 1
        add_score 100, "Account less than 1 hour old"
      elsif account_age_hours < 24
        add_score 50, "Account less than 24 hours old"
      elsif account_age_hours < 168  # 1 week
        add_score 20, "Account less than 1 week old"
      end
    end

    # Check posting frequency
    if @user.respond_to?(:posts_in_last_hour)
      posts = @user.posts_in_last_hour
      if posts > 10
        add_score 150, "Rapid posting: #{posts} posts in last hour"
      elsif posts > 5
        add_score 50, "Elevated posting rate"
      end
    end
  end
end
```

## Advanced Configurations

### Multi-Field Spam Detection

```ruby
class BlogPost
  include Splam

  # Check title with low threshold
  splammable :title, 50 do |suite|
    suite.rules = [:bad_words, :punctuation]
  end

  # Check body with higher threshold
  splammable :body, 150 do |suite|
    suite.rules = [:bad_words, :href, :bbcode, :html]
  end

  # Check author bio
  splammable :author_bio, 100 do |suite|
    suite.rules = [:href, :bad_words]
    suite.conditions = lambda { |post| post.new_record? }
  end

  attr_accessor :title, :body, :author_bio

  def spam?
    splam?(:title) || splam?(:body) || splam?(:author_bio)
  end
end
```

### Weighted Rules by Content Type

```ruby
class ForumPost
  include Splam

  splammable :content do |suite|
    suite.threshold = 120

    # Weight rules differently for forum posts
    suite.rules = {
      Splam::Rules::BadWords     => 2.0,   # Extra sensitive to bad words
      Splam::Rules::Href         => 1.5,   # Penalize links more
      Splam::Rules::Bbcode       => 0.5,   # BBCode is expected in forums
      Splam::Rules::Punctuation  => 0.3,   # Less strict on punctuation
      Splam::Rules::User         => 1.0
    }
  end
end
```

### Context-Aware Configuration

```ruby
class Comment
  include Splam

  attr_accessor :body, :context, :user

  splammable :body do |suite|
    # Configuration will be adjusted based on context
    suite.threshold = 100

    suite.conditions = lambda { |comment|
      # Adjust threshold based on context
      case comment.context
      when :support_ticket
        suite.threshold = 200  # More lenient
        suite.rules = [:href, :bbcode]  # Allow technical content
      when :public_comment
        suite.threshold = 80   # More strict
      when :forum_post
        suite.threshold = 120
        # Forums often have links and formatting
        suite.rules = {
          Splam::Rules::Href => 0.5,
          Splam::Rules::Bbcode => 0.3
        }
      end

      # Don't check internal users
      return false if comment.user&.internal?

      true
    }
  end
end

# Usage
comment = Comment.new
comment.body = "Check the logs at http://example.com/trace.txt"
comment.context = :support_ticket
comment.splam?  # => false (high threshold for support context)

comment.context = :public_comment
comment.splam?  # => possibly true (lower threshold)
```

### IP Blacklist Integration

```ruby
class Comment
  include Splam

  attr_accessor :body, :ip_address, :user

  splammable :body do |suite|
    suite.threshold = 100

    # Provide IP address to HTTP:BL rule
    suite.request = lambda { |comment|
      { remote_ip: comment.ip_address }
    }
  end
end

# Configure Project Honeypot API key
Splam::Rules::Httpbl.api_key = ENV['HTTPBL_API_KEY']

# Usage
comment = Comment.new
comment.body = "Normal text"
comment.ip_address = "1.2.3.4"  # Known spam IP

comment.splam?  # => true if IP is blacklisted
comment.splam_score  # => 250+ if in blacklist
```

## Testing

### RSpec Examples

```ruby
# spec/models/comment_spec.rb
require 'rails_helper'

RSpec.describe Comment, type: :model do
  describe 'spam detection' do
    let(:user) { create(:user) }

    it 'detects obvious spam' do
      comment = Comment.new(
        body: "Buy viagra cheap! http://spam.com http://spam2.com",
        user: user
      )

      expect(comment.splam?).to be true
      expect(comment.splam_score).to be > 100
    end

    it 'allows legitimate content' do
      comment = Comment.new(
        body: "Great article! I really learned a lot from this.",
        user: user
      )

      expect(comment.splam?).to be false
      expect(comment.splam_score).to be < 50
    end

    it 'provides scoring reasons' do
      comment = Comment.new(
        body: "Buy viagra now!!!",
        user: user
      )

      reasons = comment.splam_reasons[:body]
      expect(reasons).to include(a_string_matching(/viagra/i))
    end

    it 'skips check for trusted users' do
      trusted_user = create(:user, trusted: true)
      comment = Comment.new(
        body: "Has some suspicious text",
        user: trusted_user
      )
      comment.skip_splam_check = true

      expect(comment.splam?).to be false
    end
  end
end
```

### Test::Unit Examples

```ruby
# test/unit/comment_test.rb
require 'test_helper'

class CommentTest < ActiveSupport::TestCase
  test "detects spam with bad words" do
    comment = Comment.new(body: "Buy cheap viagra!")
    assert comment.splam?
    assert comment.splam_score > 50
  end

  test "detects spam with multiple links" do
    comment = Comment.new(
      body: "Check out http://site1.com and http://site2.com " \
            "and http://site3.com and http://site4.com"
    )
    assert comment.splam?
  end

  test "allows normal comments" do
    comment = Comment.new(
      body: "This is a helpful comment about the article."
    )
    assert_not comment.splam?
  end

  test "records spam reasons" do
    comment = Comment.new(body: "[url=http://spam.com]Click here[/url]")
    comment.splam?

    reasons = comment.splam_reasons[:body].join(" ")
    assert_match(/bbcode/i, reasons)
  end
end
```

### Factory Definitions

```ruby
# test/factories/comments.rb
FactoryBot.define do
  factory :comment do
    body { "This is a normal comment" }
    association :user

    trait :spam do
      body { "Buy viagra cheap! http://spam-site.ru #{SecureRandom.hex}" }
    end

    trait :with_links do
      body { "Check out http://example.com for more info" }
    end

    trait :suspicious do
      body { "!!!Amazing offer!!! Click here NOW!!!" }
    end
  end
end

# Usage in tests
spam_comment = create(:comment, :spam)
expect(spam_comment.splam?).to be true
```

## Monitoring and Logging

```ruby
class Comment < ActiveRecord::Base
  include Splam

  splammable :body, 100

  after_create :log_spam_score

  private

  def log_spam_score
    if splam_score > 50
      Rails.logger.info(
        "Spam check: comment_id=#{id} " \
        "score=#{splam_score} " \
        "spam=#{splam?} " \
        "user_id=#{user_id} " \
        "reasons=#{splam_reasons[:body]&.first(3)&.join('; ')}"
      )
    end

    # Send to metrics service
    if defined?(StatsD)
      StatsD.histogram('spam.score', splam_score)
      StatsD.increment('spam.detected') if splam?
    end
  end
end
```

---

For more information, see the main [README.md](README.md) and [RULES.md](RULES.md).
