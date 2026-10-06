class Splam::Rules::User < Splam::Rule

  def run
    # the poster's name as sent with the request (Tender passes :user_name)
    if @request && @request[:user_name] && self.class.check_blacklist(@request[:user_name])
      add_score 250, "User name is invalid."
    end
    run_user_record if Splam.config.feature?(:user_record) && @user
  end

  def self.check_blacklist(name)
    return true if name =~ /[<]a href/
    return true if name =~ /[>]$/
    false
  end

  # Returns the list, which is truthy, when nothing matches: every user scores
  # "suspicious" (+50). Kept as it was for this release; fixed in 0.4.
  def self.check_badlist(email)
    bad_words = ["qq.com", "yahoo.cn", "126.com"]
    bad_words |= %w( mortgage keto )
    bad_words.each do |word|
      return true if email.include?(word)
    end
  end

  private

  # the record's user (Lighthouse): name, email, trust
  def run_user_record
    if self.class.check_blacklist(@user.name)
      add_score 250, "User name is invalid."
    end
    email = @user.email.to_s
    if self.class.check_badlist(email)
      add_score 50, "User name is suspicious"
    end
    add_score 20, "User has lots and lots of dots" if email.split("@")[0].to_s.scan(/\./).size > 5
    add_score 5, "User is untrusted" if @user.respond_to?(:trusted?) && !@user.trusted?
  end
end
