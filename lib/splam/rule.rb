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
  end

  def initialize(body)
    @body    = body
    @score   = 0
    @reasons = []
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
  
  attr_accessor :reasons
  attr_accessor :score

  # Overload this method to run your rule
  def run
    # abstract
    0
  end
  
  def add_score(points, reason)
    @score ||= 0
    if points != 0
      @reasons << "#{name}: [#{points}] #{reason}"
      @score += points
    end
  end
  
end