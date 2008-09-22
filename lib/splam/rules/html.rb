class Splam::Rules::Html < Splam::Rule
  
  def run
    score = 0
    # you get points for having lots of links
    score += @body.scan(/\<[abi]/).size

    score
  end
end