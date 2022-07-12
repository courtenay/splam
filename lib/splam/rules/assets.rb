
class Splam::Rules::Assets < Splam::Rule

  def run
    return unless @request # no request available
    return unless @request[:asset_names] # 
        
    names = @request[:asset_names].split("\n")
    names.each do |name|
      if result = self.class.check_blacklist(name)
        add_score 50, "Asset matches blacklist names"
      end
    end
  end
  
  def self.check_blacklist(name)
    return true if name =~ /canon.jpg/
    return true if name =~ /yahoo_support/i
    false
  end
    
end
