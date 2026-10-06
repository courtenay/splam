require 'json'

# Logistic regression over a Splam::Result's features:
#   probability = 1 / (1 + e^-(bias + sum(weight * transform(feature))))
# with weights trained offline (script/train_linear.rb) and kept in a JSON file:
#   { "bias": -2.3,
#     "features": { "body.rule.bad_words": { "weight": 0.41, "transform": "slog" }, ... } }
# Transforms: "raw" (as is), "slog" (sign(x) * log(1 + |x|), for rule points
# that run from -100 to 10,000), "clip" (into [min, max], default -50..50).
# Features missing from a result count as 0.
class Splam::LinearScorer
  attr_reader :bias, :features

  def self.load(path)
    from_hash(JSON.parse(File.read(path)))
  end

  def self.from_hash(h)
    new(h["bias"], h["features"])
  end

  def initialize(bias, features)
    @bias = bias.to_f
    @features = features
  end

  def logit(values)
    @features.inject(@bias) { |z, (name, spec)| z + contribution(spec, values[name]) }
  end

  def probability(values)
    Splam::TextModel.probability(logit(values))
  end

  # [[name, weight * transformed value], ...], largest effect first
  def contributions(values)
    @features.map { |name, spec| [name, contribution(spec, values[name])] }.
      reject { |_, c| c.zero? }.sort_by { |_, c| -c.abs }
  end

  def to_hash
    { "bias" => @bias, "features" => @features }
  end

  def self.transform(spec, x)
    x = x.to_f
    case spec["transform"]
    when "slog" then x < 0 ? -Math.log(1 - x) : Math.log(1 + x)
    when "clip" then [[x, (spec["max"] || 50).to_f].min, (spec["min"] || -50).to_f].max
    else x
    end
  end

  private

  def contribution(spec, value)
    return 0.0 if value.nil?
    spec["weight"].to_f * self.class.transform(spec, value)
  end
end
