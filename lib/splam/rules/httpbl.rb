require 'resolv'
require 'timeout'

# Liberally copied from https://github.com/bpalmen/httpbl/blob/master/lib/httpbl.rb
class Splam::Rules::Httpbl < Splam::Rule
  class << self
    attr_accessor :api_key
  end

  def run
    return unless @request # no ip available
    return unless @request[:remote_ip] # no ip available
    
    ip = @request[:remote_ip]
    
    if result = self.class.check_blacklist(ip)
      add_score 250, "IP address (#{ip}) appears in ProjectHoneypot blacklist. (#{result.inspect})"
    end
  end
  
  def self.check_blacklist(ip)
    return if ip == "127.0.0.1"
    result = resolve(ip)
    return if result == "127.0.0.1"
    response = result.split(".").collect!(&:to_i)
    
    # responses:
    # a, b, c, d
    # a = 127 if success
    # b = days since last activity
    # c = threat score, 0..255 (0 is not threat)
    # d = type of visitor
    raise "Bad httpbl request format!" if response[0] != 127
    if response[3] > 0 || response[2] > 100
      return({ days: response[1], score: response[2] })
    end

    # no httpbl result, however..
    @cache = REDIS if defined?(REDIS)
    result = @cache && @cache["ip.#{ip}"]
    if result
      return({ cache: result })
    end
  end
  
  def self.resolve(ip)
    query = "#{api_key}.#{ip.split('.').reverse.join('.')}.dnsbl.httpbl.org"
    Timeout::timeout(0.5) do
      begin
        Resolv::DNS.new.getaddress(query).to_s
      rescue Resolv::ResolvError
        "127.0.0.0"
      end
    end
  rescue Errno::ECONNREFUSED
    # derp
  end
  
end
