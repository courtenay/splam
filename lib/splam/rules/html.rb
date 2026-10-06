class Splam::Rules::Html < Splam::Rule
  
  def run
    # you get points for having lots of links
    add_score @body.scan(/\<[abi]/).size, "Lots of <a> <b> or <i> links"
    
    # stupid fools!
    add_score 5 * Splam::LinearScan.bold_link_count(@body), "<b> inside an <a>" # /<a[^>]*><b>/
    
    add_score(200, "Entire body is an HTML tag") if @body.strip =~ /\A[<][^>]*[>]\Z/

    if Splam.config.feature?(:trailing_tag) && ends_in_tag?(@body.strip)
      add_score(100, "Body with a trailing link")
      # (before 0.5 `if @body.scan(/[!]/)` was true for any body)
      add_score(20, "Don't get too excited.") if @body.include?("!")
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

  private

  # text =~ /[<][^>]*[>]\Z/ in linear time (the regex retries from every "<"):
  # the text ends with ">" and its last "<" comes after the ">" before that
  def ends_in_tag?(text)
    return false unless text.end_with?(">")
    lt = text.rindex("<", text.size - 2)
    return false unless lt
    gt = text.rindex(">", text.size - 2)
    gt.nil? || lt > gt
  end
end
