class Splam::Rule
  class << self
    attr_writer   :splam_key

    # Global set of rules for all splammable classes.  By default it is an array of all Splam::Rule subclasses.
    # It can be set to a subset of all rules, or even a hash with specified weights.
    #   self.default_rules = [:bad_words, :bbcode]
    #   self.default_rules = {:bad_words => 0.5, :bbcode => 7}
    #
    attr_accessor :default_rules

    # Index linking all splam_keys to the rule classes.  This is populated automatically.
    attr_reader   :rules

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

  def initialize(suite, record, weight = 1.0)
    @suite, @weight, @score, @reasons, @body = suite, weight, 0, [], record.send(suite.body)
  end
  
  def name
    self.class.splam_key
  end

  def self.inherited(_subclass)
    @rules      ||= {}
    @default_rules ||= []
    @default_rules << _subclass
    _subclass.splam_key
    super
  end

  attr_reader   :suite, :body, :weight
  attr_accessor :reasons, :score

  # Overload this method to run your rule.  Call #add_score to modify the suite's splam score.
  #
  #   def run
  #     add_score -5, 'water'
  #     add_score  5, 'PBR'
  #     add_score 10, 'black butte'
  #     add_score 30, 'red wine'
  #     add_score 95, 'everclear'
  #   end
  #
  def run
  end
  
  def add_score(points, reason)
    @score ||= 0
    if points != 0
      @reasons << "#{name}: [#{points}#{" * #{weight}" if weight != 1}] #{reason}"
      points = points * weight.to_i
      @score += points
    end
  end
end