# encoding: UTF-8
# The word lists in data/: one entry per line, a string or re:/source/flags
# for a Regexp; blank lines and # comments are skipped.
module Splam::WordList
  DIR = File.expand_path("../../../data", __FILE__)

  def self.read(path)
    path = File.join(DIR, path) unless path.start_with?("/")
    File.read(path, :encoding => "UTF-8").split("\n").map(&:strip).reject { |l| l.empty? || l.start_with?("#") }.map do |line|
      if line =~ %r{\Are:/(.*)/([imx]*)\z}
        options = 0
        options |= Regexp::IGNORECASE if $2.include?("i")
        options |= Regexp::MULTILINE if $2.include?("m")
        options |= Regexp::EXTENDED if $2.include?("x")
        Regexp.new($1, options)
      else
        line
      end
    end
  end
end
