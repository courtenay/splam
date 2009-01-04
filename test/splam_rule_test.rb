require File.join(File.dirname(__FILE__), 'test_helper')

module FooBar
  class SampleRule < Splam::Rule
  end

  class NamedRule < Splam::Rule
    self.splam_key = :special_name
  end
end

class SplamRuleTest < Test::Unit::TestCase
  def test_implicit_splam_key
    assert_equal FooBar::SampleRule, Splam::Rule.rules[:sample_rule]
  end

  def test_explicit_splam_key
    assert_equal FooBar::NamedRule, Splam::Rule.rules[:special_name]
  end
end