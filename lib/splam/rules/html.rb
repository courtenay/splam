class Splam::Rules::Html < Splam::Rule
  
  def run
    # you get points for having lots of links
    add_score @body.scan(/\<[abi]/).size, "Lots of <a> <b> or <i> links"
    
    # stupid fools!
    add_score 5 * @body.scan(/<a[^>]*><b>/).size, "<b> inside an <a>"
    
    add_score(200, "Entire body is an HTML tag") if @body =~ /^[<][^>]*[>]$/
  end
end