class Splam::Rules::Bbcode < Splam::Rule

  def run
    add_score 10 * @body.scan("showpost.php?p=").size, "Linking to a shitty forum"
    # add_score 10 * @body.scan("\r\n").size, "Poorly formed POST (\\r\\n)"
    add_score 40 * @body.scan("[url=").size, "URL" # no URLS for you!!
    add_score 40 * @body.scan("[URL=").size, "URL" # no URLS for you!!
    add_score 40 * @body.scan("[url=http").size, "Shitty URL/html" # another 10 points for shitty bbcode html
    add_score 40 * @body.scan("[URL=http").size, "Shitty URL/html" # another 10 points for shitty bbcode html
    add_score 10 * @body.scan(/\[[bai]/).size, "b/a/i tag"
  end
end