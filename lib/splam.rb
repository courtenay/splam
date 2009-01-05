# Splam
#require File.dirname(__FILE__) + "/splam/rule"
#require File.dirname(__FILE__) + "/splam/rules"
#require File.dirname(__FILE__) + "/splam/rules/russian"

module Splam
  def self.included(base)
    # Autoload all files in rules
    # This is bad, mkay
    Dir["#{File.dirname(__FILE__)}/splam/rules/*.rb"].each do |f|
      require f
    end
    base.send :extend, ClassMethods
  end
  
  module ClassMethods
    def splam; @splam; end
    def splammable(fieldname, threshold=100, conditions=nil)
      run_rules = []
      # todo: run only certain rules
      #  e.g. splammable :body, 100, [ :chinese, :html ]
      # todo: define some weighting on the model level
      #  e.g. splammable :body, 50, { :russian => 2.0 }
      @splam = {}
      @splam[:body] = fieldname
      @splam[:rules] = Splam::Rule.subclasses
      @splam[:threshold] = threshold
      @splam[:fieldname] = fieldname
      @splam[:conditions] = conditions
    end
  end
  # uhm attr_accessor?
  def splam_score; @splam_score; end
  def splam_reasons; @splam_reasons; end
  
  def splam?
    splam = self.class.splam || raise("Splam is not initialized")
    return false if splam[:conditions] && ! splam[:conditions].call(self)
    return false if skip_splam_check?
    @splam_score = 0
    @splam_reasons = []
    body = send(splam[:body])
    return false if body.nil?
    splam[:rules].each do |rule_class|
      worker = rule_class.new(body)
      worker.run
      @splam_score += worker.score
      @splam_reasons << worker.reasons
    end
    @splam_score > splam[:threshold]
  end
  attr_accessor :skip_splam_check
  def validates_as_spam
    errors.add(self.class.splam[:fieldname], "looks like spam.") if (!skip_splam_check? && splam?)
  end
  
  def skip_splam_check?
    skip_splam_check.to_i > 0
  end
end