class Splam::Rules::LineLength < Splam::Rule
  
  def name
    "Line length"
  end
  
  # Penalize long line lengths.
  def run
    lines = @body.split("\n")
    lines.each do |line|
      next if line =~ /\A\s{4,}/ # ignore code blocks

      multiplier = (lines.size == 1) ? 10 : 1 # one line? fail.
        
      
      # 1 point for each 40 chars in a line.
      hits = (line.size / 40) * multiplier
      add_score hits, "lines over 40 chars"
      
      # 2 more points if line is longer than 80
      hits = (line.size / 80) * 2 * multiplier
      add_score hits, "lines over 80 chars"

    end
  end
end