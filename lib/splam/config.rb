# Per-app settings. Apps with different customers can score differently:
#
#   Splam.configure do |c|
#     c.profile = :lighthouse                    # a named preset, see PROFILES
#     c.weights = { :bad_words => 0.5, :href => 2 } # rule weights, overriding the preset
#     c.bad_word_score = 12
#   end
#
# A suite that names its own weights (`s.rules = { :html => 3 }`) keeps them;
# config weights apply to rules given without one.
module Splam
  class Config
    # Each profile: rule weights, bad_word_score, opt-in rules it enables, and
    # behaviour switches that rules read with Splam.config.feature?(name).
    PROFILES = {
      :default => {
        :bad_word_score => 10,
        :rules          => [],
        :features       => [],
      },
      # Lighthouse's tuning (splam 0.3.0, 1d42b75): more word genres, a harsher
      # bad-word base, lower link-count thresholds, trailing-tag checks, the
      # user-record checks, and the Fuzz and LineLength rules.
      :lighthouse => {
        :bad_word_score => 15,
        :rules          => [:fuzz, :line_length],
        :features       => [:lighthouse_words, :trailing_tag, :lighthouse_href, :user_record],
      },
    }

    attr_reader :profile
    attr_writer :bad_word_score
    attr_accessor :weights

    def initialize
      self.profile = :default
      @weights = {}
    end

    def profile=(name)
      raise ArgumentError, "unknown splam profile #{name.inspect}" unless PROFILES.key?(name.to_sym)
      @profile = name.to_sym
    end

    def preset
      PROFILES[@profile]
    end

    def bad_word_score
      @bad_word_score || preset[:bad_word_score]
    end

    def feature?(name)
      preset[:features].include?(name)
    end

    # opt-in rules (Rule.opt_in?) run only when the profile names them
    def rule_enabled?(rule)
      !rule.opt_in? || preset[:rules].include?(rule.splam_key)
    end

    def weight_for(rule)
      w = weights[rule.splam_key] || weights[rule.splam_key.to_s]
      w.nil? ? nil : w.to_f
    end
  end

  def self.config
    @config ||= Config.new
  end

  def self.configure
    yield config
    config
  end

  # back to defaults (tests)
  def self.reset_config!
    @config = Config.new
  end
end
