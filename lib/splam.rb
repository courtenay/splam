# Splam
#require File.dirname(__FILE__) + "/splam/rule"
#require File.dirname(__FILE__) + "/splam/rules"
#require File.dirname(__FILE__) + "/splam/rules/russian"

module Splam
  def self.included(base)
    # Autoload all files in rules
    Dir["lib/splam/rules/*.rb"].each do |f|
      require f
    end
  end
  
  def splammable(fieldname, rules = [:all])
    run_rules = []
    if rules == [:all]
      run_rules = Splam::Rule.subclasses
    else
    # todo
    #  run_rules = Splam::Rule.subclasses.select {|r| r.name == ??? }
    end
    body = send(fieldname)
    score = 0
    reasons = []
    Splam::Rule.subclasses.each do |_subclass|
      worker = _subclass.new(body)
      score += worker.run
      reasons << worker.reasons
    end
    score
  end
end