class Splam::Rules::Html < Splam::Rule
  
  def run
    # you get points for having lots of links
    add_score @body.scan(/\<[abi]/).size, "Lots of <a> <b> or <i> links"
  end
end