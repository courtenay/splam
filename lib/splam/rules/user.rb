
class Splam::Rules::User < Splam::Rule

  def run
    return unless @user

    name = @user.name
    if result = self.class.check_blacklist(@user.name)
      add_score 250, "User name is invalid."
    end
    if result = self.class.check_badlist(@user.email)
      add_score 50, "User name is suspicious"
    end
    add_score "20", "User has lots and lots of dots" if @user.email.split("@")[0].scan(/\./).size > 5
    add_score 5, "User is untrusted" if !@user.trusted?
    
  end
  
  def self.check_blacklist(name)
    return true if name =~ /[<]a href/
    return true if name =~ /[>]$/

    false
  end

  def self.check_badlist(email)
    bad_words = ["qq.com", "yahoo.cn", "126.com"]
    bad_words |= %w( mortgage keto )
    bad_words.each do |word|
      return true if email.include?(word)
    end
  end

end
