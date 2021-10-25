# Splam
module Splam
end

require 'rubygems'
gem 'activesupport'
require 'active_support/inflector'

require File.dirname(__FILE__) + "/splam/rule"
require File.dirname(__FILE__) + "/splam/rules"
require File.dirname(__FILE__) + "/splam/rules/russian"


module Splam
  class Suite < Struct.new(:body, :rules, :threshold, :conditions)
    # Should be a Rack::Request, in case you want to inspect user agents and whatnot
    # unimplemented, cry about it fanboy!
    attr_accessor :request
    
    # struct
    # attr_reader :body
    attr_reader :score
    attr_reader :reasons

    def initialize(body, rules, threshold, conditions, &block)
      super(body, rules, threshold, conditions)
      block.call(self) if block
      self.rules = self.rules.inject({}) do |memo, (rule, weight)|
        if (rule.is_a?(Class) && rule.superclass == Splam::Rule) || rule = Splam::Rule.rules[rule]
          memo[rule] = weight || 1.0
        else
          raise ArgumentError, "Invalid rule: #{rule.inspect}"
        end
        memo
      end
    end

    def run(record, request)
      score, reasons = 0, []
      rules.each do |rule_class, weight|
        weight ||= 1
        worker   = rule_class.run(self, record, weight, request)
        score   += worker.score
        reasons << worker.reasons
      end
      [score, reasons]
    end

    def splam?(score)
      raise "No threshold" if threshold.nil?
      raise "No score?"    if score.nil?
      score >= threshold
    end
  end

  def self.included(base)
    # Autoload all files in rules
    # This is bad, mkay
    Dir["#{File.dirname(__FILE__)}/splam/rules/*.rb"].each do |f|
      require f
    end
    require_relative "splam/ngram"
    base.send :extend, ClassMethods
  end
  
  module ClassMethods
    def splam_suites; @splam_suites; end
    # Set #body attribute as splammable with default threshold of 100
    #   splammable :body
    # 
    # Set #body attribute as splammable with custom threshold
    #   splammable :body, 50
    #
    # Set #body splammable with threshold and a conditions block?
    #   splamamble :body, 50, lambda { |record| record.skip_splam_check }
    #
    # Set any Splam::Suite options
    #   splammable :body do |splam|
    #     splam.threshold  = 150
    #     splam.conditions = lambda { |r| r.body.size.zero? }
    #     # Set rules with #splam_key value
    #     splam.rules     = [:chinese, :html]
    #     # Set rules with Class instances
    #     splam.rules     = [Splam::Rules::Chinese]
    #     # Mix and match, we're all friends here
    #     splam.rules     = [Splam::Rules::Chinese, :html]
    #     # Specify optional weights
    #     splam.rules     = {Splam::Rules::Chinese => 1.2, :html => 5.0}
    #
    def splammable(fieldname, threshold=100, conditions=nil, &block)
      # todo: run only certain rules
      #  e.g. splammable :body, 100, [ :chinese, :html ]
      # todo: define some weighting on the model level
      #  e.g. splammable :body, 50, { :russian => 2.0 }
      @splam_suites ||= []
      @splam_suites << Suite.new(fieldname, Splam::Rule.default_rules, threshold, conditions, &block)
    end

    def validates_as_splam
      # errors.add(self.class.splam_suite.body, "looks like spam.") if (!skip_splam_check? && splam?)
    end
  
  end

  attr_accessor :skip_splam_check
  attr_reader   :splam_score, :splam_reasons

  def splam_score
    @splam_score || run_splam_suite(:score) || 0
  end

  def splam_scores
    @splam_scores
  end

  def splam_reasons
    @splam_reasons || run_splam_suite(:reasons) || []
  end

  def splam?(fieldname = nil)
    scores = run_splam_suite(:scores) # ask yourself, do you want this to be cached for each record instance or not?
    if fieldname
      score = scores[fieldname]
      return false if score.nil?
      return self.class.splam_suites.any? { |ss|
        ss.body == fieldname && ss.splam?(score)
      }
    else
      score = scores.sum {|k,v| v.to_i }
      self.class.splam_suites.any? { |ss|
        ss.splam?(scores[ss.body])
      }
    end
  end

protected
  def run_splam_suite(attr_suffix = nil)
    splam_suites = self.class.splam_suites || raise("Splam::Suite is not initialized")
    return false if splam_suites.empty?

    @splam_score, @splam_reasons, @splam_scores = 0, {}, {}
    splam_suites.each do |splam_suite|
      next if splam_suite.conditions && splam_suite.conditions.call(self) == false
      next if skip_splam_check
      next if send(splam_suite.body).nil?

      @request = splam_suite.request.call(self) if splam_suite.request
      score, reasons  = splam_suite.run(self, @request)
      @splam_score   += score
      @splam_reasons[splam_suite.body] ||= []
      @splam_reasons[splam_suite.body] |= reasons
      @splam_scores[splam_suite.body] = score
    end
    instance_variable_get("@splam_#{attr_suffix}") if attr_suffix
  end
  
  def skip_splam_check?
    # This enables us to use a checkbox
    skip_splam_check.to_i > 0
  end
end