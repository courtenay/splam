# encoding: UTF-8
# The text a suite checks, prepared once and shared by every rule: a valid
# UTF-8 copy, its downcased form, and the link scans (Splam::LinearScan), each
# computed the first time a rule asks.
class Splam::Document
  attr_reader :text

  def initialize(text)
    text = text.to_s
    # posted bodies aren't checked for valid UTF-8, and scan/downcase raise on it
    text = text.scrub('') unless text.valid_encoding?
    @text = text
  end

  def downcased
    @downcased ||= @text.downcase
  end

  # text.scan(/<a[^>]+>(.*?)<\/a>/), on the text as given or downcased
  def link_texts(downcase = false)
    (@link_texts ||= {})[downcase] ||= Splam::LinearScan.link_texts(downcase ? downcased : @text)
  end

  # text.scan(/<a(.*?)>/), on the text as given or downcased
  def link_attributes(downcase = false)
    (@link_attributes ||= {})[downcase] ||= Splam::LinearScan.link_attributes(downcase ? downcased : @text)
  end

  # Splam::Ngram's word tokens of the stripped text
  def tokens
    @tokens ||= Splam::Ngram.tokenize(@text.strip)
  end
end
