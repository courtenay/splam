class Splam::Rules::LineLength < Splam::Rule
  
  def name
    "Line length"
  end
  
  # Penalize long line lengths.
  def run
    @body.split("\n").each do |line|
      # 1 point for each 40 chars in a line.
      hits = (line.size / 40)
      add_score hits, "lines over 40 chars"
      
      # 2 more points if line is longer than 80
      hits = (line.size / 80) * 2
      add_score hits, "lines over 80 chars"
    end
  end
end