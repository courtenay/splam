class Splam::Rules::Html < Splam::Rule
  
  def run
    # you get points for having lots of links
    add_score @body.scan(/\<[abi]/).size, "Lots of <a> <b> or <i> links"
    
    # stupid fools!
    add_score 5 * @body.scan(/<a[^>]*><b>/).size, "<b> inside an <a>"
    
    add_score(200, "Entire body is an HTML tag") if @body.strip =~ /\A[<][^>]*[>]\Z/

    if @body.strip =~ /[<][^>]*[>]\Z/
      add_score(100, "Body with a trailing link")
      add_score(20, "Don't get too excited.") if @body.scan(/[!]/)
    end

    # html comment: /* word word word=\nword word word=\nword word */
    # with > 50 words, to make the body look longer
    if @body =~ /(\/[*]\s+([[:word:]=]{5,}\s+){50,})[*]\//
      add_score 200, "Lots of long words in html comment, no punctuation"
    end
    if @body =~ /(target[=]\"([[:word:]=]{4,}\s+){3,})/
      add_score 200, "Lots of words in 'target' link attribute"
    end
  end
end
