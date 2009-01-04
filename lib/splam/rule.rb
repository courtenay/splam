class Splam::Rule
  class << self
    attr_writer :splam_key
    attr_reader :subclasses
    attr_reader :rules

    def splam_key
      @splam_key || (self.splam_key = name.demodulize.underscore.to_sym)
    end

    def splam_key=(value)
      Splam::Rule.rules.delete(@splam_key) if @splam_key
      Splam::Rule.rules[value] = self
      @splam_key               = value
      value
    end

    def run(*args)
      rule = new(*args)
      rule.run
      rule
    end
  end

  def initialize(body, weight = 1.0)
    @body, @weight, @score, @reasons = body, weight, 0, []
  end
  
  def name
    self.class.splam_key
  end

  def self.inherited(_subclass)
    @rules      ||= {}
    @subclasses ||= []
    @subclasses << _subclass
    _subclass.splam_key
    super
  end

  attr_reader   :body, :weight
  attr_accessor :reasons, :score

  # Overload this method to run your rule
  def run
    # abstract
    0
  end
  
  def add_score(points, reason)
    @score ||= 0
    if points != 0
      @reasons << "#{name}: [#{points}#{" * #{weight}" if weight != 1}] #{reason}"
      points = points * weight
      @score += points
    end
  end
  
end