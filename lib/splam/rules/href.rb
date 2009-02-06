# This plugin checks for links in the text, and adds scores for having many links,
# and 
class Splam::Rules::Href < Splam::Rule
  
  def run
    # add_score 3 * @body.scan("href=http").size, "Shitty html 'href=http'" # 3 points for shitty html
    add_score 15 * @body.scan(/href\=\s*http/).size, "Shitty html 'href=http'" # 15 points for shitty html
    add_score 15 * @body.scan(/href\="\s+http/).size, "Shitty html 'href=\" http'" # 15 points for shitty html
    add_score 50 * @body.scan(/\A<a.*?<\/a>\Z/).size, "Single link post'"      # 50 points for shitty

    link_count = @body.scan("http://").size
    add_score 1 * link_count, "Matched 'http://'" # 1 point per link
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
      'pl' => 8,
      'info' => 20, 
      'biz'  => 40 # no-one uses these for reals
    }
    suspicious_sites = {
      'cnn' => 10, # Honestly, who links to CNN?
      'bbc' => 10
    }
    
    tokens = @body.split(" ")
    if tokens[-1] =~ /^http:\/\//
      add_score 10, "Text ends in a http token"
      add_score 50, "Text ends in a http token and only has one token" if link_count == 1
    end
    
    @body.scan(/http:\/\/(.*?)[\/\]?]/) do |match|
      # $stderr.puts "checking #{match}"
      if domain = match.to_s.split(".")
        tld = domain[-1]

        if found = suspicious_top_level_domains[tld]
          add_score found, "Suspicious top-level domain: '#{tld}'"
        end
        
        if found = suspicious_sites[domain[-2]]
          add_score found, "Suspicious hostname: '#{domain[-2]}'"
        end
      end
    end
  end
end