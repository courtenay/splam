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
      @splam_key || (self.splam_key = Splam::Rule.key_for(name))
    end

    def splam_key=(value)
      Splam::Rule.rules.delete(@splam_key) if @splam_key
      Splam::Rule.rules[value] = self
      @splam_key               = value
      value
    end

    # Opt-in rules run only when Splam.config enables them (a profile's :rules)
    # or a suite names them. Override in the rule class.
    def opt_in?
      false
    end

    def run(*args)
      rule = new(*args)
      rule.run
      rule
    end
  end

  # "Splam::Rules::BadWords" => :bad_words, as ActiveSupport's
  # demodulize.underscore made it (without app-defined acronyms)
  def self.key_for(class_name)
    class_name.to_s.split("::").last.
      gsub(/([A-Z\d]+)([A-Z][a-z])/, '\\1_\\2').
      gsub(/([a-z\d])([A-Z])/, '\\1_\\2').
      tr("-", "_").downcase.to_sym
  end

  def initialize(suite, record, weight = 1.0, request = nil)
    @suite, @weight, @score, @reasons, @body, @request = suite, weight, 0, [], record.send(suite.body), request
    # the record's user, for rules that inspect it (the :user_record feature); not every record has one
    @user = record.respond_to?(:user) ? record.user : nil
    # posted bodies aren't checked for valid UTF-8, and scan/downcase raise on it
    @body = @body.scrub('') if @body.is_a?(String) && !@body.valid_encoding?
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
      # a fractional weight used to truncate (weight.to_i: 0.5 counted as 0)
      points = points * weight unless weight == 1
      
      # avoid int overflow
      points = 10_000 if points > 10_000
      
      @score += points
    end
  end

  def line_safe?(string)
    ([
      /\.dylib\b/,
      /\b0x[0-9a-f]{6,16}\b/i,
      /\b\/Applications\//,
      /\b\/System\/Library\//,
      /\bLibrary\/Application Support\//
    ].map {|r| r.match string }).compact.size > 0
  end

end
