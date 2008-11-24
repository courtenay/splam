class Splam::Rule
  class << self
    attr_reader :subclasses
  end

  def initialize(body)
    @body = body
    @score = 0
    @reasons = []
  end
  
  def name
    self.class.name.split("::")[-1]
  end
  
  def self.inherited(_subclass)
    @subclasses ||= []
    @subclasses << _subclass
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