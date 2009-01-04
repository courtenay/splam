# Splam
#require File.dirname(__FILE__) + "/splam/rule"
#require File.dirname(__FILE__) + "/splam/rules"
#require File.dirname(__FILE__) + "/splam/rules/russian"

require 'rubygems'
gem 'activesupport'
require 'active_support/inflector'

module Splam
  class Suite < Struct.new(:body, :rules, :threshold, :conditions)
    attr_reader :score
    attr_reader :reasons

    def run(body)
      score, reasons = 0, []
      rules.each do |rule_class|
        worker = rule_class.new(body)
        worker.run
        score   += worker.score
        reasons << worker.reasons
      end
      [score, reasons]
    end

    def splam?(score)
      score > threshold
    end
  end

  def self.included(base)
    # Autoload all files in rules
    # This is bad, mkay
    Dir["#{File.dirname(__FILE__)}/splam/rules/*.rb"].each do |f|
      require f
    end
    base.send :extend, ClassMethods
  end
  
  module ClassMethods
    def splam_suite; @splam_suite; end
    def splammable(fieldname, threshold=100, conditions=nil, &block)
      # todo: run only certain rules
      #  e.g. splammable :body, 100, [ :chinese, :html ]
      # todo: define some weighting on the model level
      #  e.g. splammable :body, 50, { :russian => 2.0 }
      @splam_suite = Suite.new(fieldname, Splam::Rule.subclasses, threshold, conditions)
      block.call(@splam_suite) if block
    end
  end

  attr_accessor :skip_splam_check
  attr_reader   :splam_score, :splam_reasons

  def splam_score
    @splam_score || run_splam_suite(:score) || 0
  end

  def splam_reasons
    @splam_reasons || run_splam_suite(:reasons) || []
  end

  def splam?
    # run_splam_suite # ask yourself, do you want this to be cached for each record instance or not?
    self.class.splam_suite.splam?(splam_score)
  end

  def validates_as_spam
    errors.add(self.class.splam_suite.body, "looks like spam.") if (skip_splam_check.nil? && splam?)
  end

protected
  def run_splam_suite(attr_suffix = nil)
    splam_suite = self.class.splam_suite || raise("Splam::Suite is not initialized")
    return false if splam_suite.conditions && ! splam_suite.conditions.call(self)
    return false if skip_splam_check
    body = send(splam_suite.body)
    return false if body.nil?
    @splam_score, @splam_reasons = splam_suite.run(body)
    instance_variable_get("@splam_#{attr_suffix}") if attr_suffix
  end
end