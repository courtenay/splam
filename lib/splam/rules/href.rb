require 'uri'
# This plugin checks for links in the text, and adds scores for having many links,
class Splam::Rules::Href < Splam::Rule
  
  def run
    # add_score 3 * @body.scan("href=http").size, "Shitty html 'href=http'" # 3 points for shitty html
    add_score 50 * @body.scan(/href\=\s*http/).size, "Shitty html 'href=http'" # 15 points for shitty html
    add_score 35 * @body.scan(/href\="\s+http/).size, "Shitty html 'href=\" http'" # 15 points for shitty html
    add_score 50 * @body.scan(/\A<a.*?<\/a>\Z/).size, "Single link post'"      # 50 points for shitty

    link_count = @body.scan("http://").size + @body.scan("https://").size
    add_score 1 * link_count, "Matched 'http[s]://'" # 1 point per link
    add_score 50, "More than 10 links" if link_count > 10  # more than 10 links? spam.
    add_score 100, "More than 20 links" if link_count > 20 # more than 20 links? definitely spam.
    add_score 1000, "More than 50 links" if link_count > 50 # more than 20 links? definitely spam.
        
    # Modify these scores to weight certain problematic domains.
    # You may need to modify these for your application
    suspicious_top_level_domains = {
      'ru' => 20,  # Russian? spammer.
      'cn' => 20,  # Chinese? spammer.
      'us' => 8,   # .us ? possibly spam
      'it' => 5,
      'tk' => 20,
      'eu' => 20,
      'pl' => 8,
      'info' => 20, 
      'biz'  => 40 # no-one uses these for reals
    }
    suspicious_sites = {
      'cnn' => 10, # Honestly, who links to CNN?
      'bbc' => 10,
      'ask' => 10,
      'sharemyphotos' => 20,
      'youtube' => 20,
      'wordpress' => 20
    }
    
    tokens = @body.split(" ")
    if tokens[-1] =~ /^https?:\/\//
      add_score 10, "Text ends in a http token"
      add_score 50, "Text ends in a http token and only has one token" if link_count == 1
    end
    
    lines = body.split
    if lines.size == 1 && lines[0] =~ /^https?[:]\/\//
      add_score 50, "Text comprises only a link"
    end
    lines.each do |line|
      line.split(" ").each_with_index do |token,i|
        if token =~ /^https?[:]/
        begin
          uri = URI.parse(token)
          
          if !uri.host
            add_score 25, "Bad domain? #{token}"
          else
            if found = suspicious_top_level_domains[uri.host.split(".")[-1]]
              add_score found, "Suspicious top-level domain: '#{token}'"
            end

            if found = suspicious_sites[uri.host.split(".")[-2]]
              add_score found, "Suspicious hostname: '#{token}'"
            end
          end
          if uri.path == "/"
            add_score 15, "Link with no path part: #{token}"
          end
          
        rescue URI::InvalidURIError
          add_score 25, "Bad/unparseable URI: #{token}"
        end
      end
    end
    end
  end
end