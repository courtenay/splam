# This plugin checks for links in the text, and adds scores for having many links,
# and 
class Splam::Rules::Href < Splam::Rule
  
  def run
    score = 3 * @body.scan("href=http").size # 3 points for shitty html
    link_count = @body.scan("http://").size
    score += 1 * link_count # 1 point per link
    score += 50 if link_count > 10  # more than 10 links? spam.
    score += 100 if link_count > 20 # more than 20 links? definitely spam.
    
    # Modify these scores to weight certain problematic domains.
    # You may need to modify these for your application
    suspicious_domains = {
      'ru' => 20,  # Russian? spammer.
      'cn' => 20,  # Chinese? spammer.
      'us' => 8,   # .us ? possibly spam
      'it' => 5,
      'pl' => 8,
      'info' => 20, 
      'biz' => 20
    }

    @body.scan(/http:\/\/(.*?)[\/\]\s]/) do |match|
      # $stderr.puts "checking #{match}"
      if domain = match.to_s.split(".")[-1]
        # $stderr.puts "Found domain '#{domain}'"
        if found = suspicious_domains[domain]
          # $stderr.puts "Found match for bad domain: #{match} "
          score += found
        end
      end
    end
    score
  end
end