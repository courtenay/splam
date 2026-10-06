# What checking a record found: the summed score (Classic), each rule's
# reasons, the features (field.rule.<key>, field.<rule feature>, the app's
# extra features, text.log_odds) and, when Splam.config.scorer is set, the
# probability it gives.
class Splam::Result
  attr_reader :score, :reasons, :features, :fields

  def initialize(score, reasons, features, fields)
    @score, @reasons, @features, @fields = score, reasons, features, fields
  end

  # nil without a scorer, or when no suite ran
  def probability
    return nil if @fields.empty? || Splam.config.scorer.nil?
    @probability ||= Splam.config.scorer.probability(@features)
  end

  # the features that moved the probability most, [[name, contribution], ...]
  def top_features(n = 5)
    return [] if @fields.empty? || Splam.config.scorer.nil?
    Splam.config.scorer.contributions(@features).first(n)
  end
end
