class Splam::Rules::GeoIP < Splam::Rule

  def run
    return unless @request # no ip available
    return unless @request[:remote_ip] # no ip available
    
    ip = @request[:remote_ip]
    return if ip == "127.0.0.1"
    
    if result = self.class.check_blacklist(ip)
      add_score 120, "IP address (#{ip}) appears to be from a suspicious country (#{result})"
    end
  end
  
  def self.check_blacklist(ip)
    bad_countries = ["Pakistan", "India", "Bangladesh"]
    c = country(ip)
    
    return false if c.nil? # hmm?
    return c if bad_countries.include? c.country_name
    return false
  end

  def self.country(ip)
    g = GeoIP.new(File.join(Rails.root, "lib", "splam", "GeoLiteCity.dat"))
    g.city(ip)
  end
    
end
