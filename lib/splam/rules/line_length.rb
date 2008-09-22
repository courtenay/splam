class Splam::Rules::LineLength < Splam::Rule
  
  # Penalize long line lengths.
  def run
    score = 0
    @body.split("\n").each do |line|
      # 1 point for each 40 chars in a line.
      score += (line.size / 40)
      
      # 2 more points if line is longer than 80
      score += (line.size / 80) * 2
    end
    score
  end
end