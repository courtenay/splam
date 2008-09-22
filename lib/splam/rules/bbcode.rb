class Splam::Rules::Bbcode < Splam::Rule
  
  def run
    score = 40 * @body.scan("[url=").size # no URLS for you!!
    score = 40 * @body.scan("[URL=").size # no URLS for you!!
    score += 40 * @body.scan("[url=http").size # another 10 points for shitty bbcode html
    score += 40 * @body.scan("[URL=").size # another 10 points for shitty bbcode html
    score += 10 * @body.scan(/\[[bai]/).size
  end
end