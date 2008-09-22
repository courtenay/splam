class Splam::Rule
  class << self
    attr_reader :subclasses
  end

  def initialize(body)
    @body = body
    @reasons = []
  end
  
  def self.inherited(_subclass)
    $stderr.puts "Inherited #{_subclass}"
    @subclasses ||= []
    @subclasses << _subclass
    super
  end
  
  attr_accessor :reasons

  # Overload this method to run your rule
  def run
    # abstract
    0
  end

end