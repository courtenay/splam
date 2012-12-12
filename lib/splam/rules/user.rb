class Splam::Rules::User < Splam::Rule
  
  def run
    bad_words = ["qq.com", "yahoo.cn", "126.com"]
    bad_words |= %w( mortgage )

    bad_words.each do |word|
      add_score 50, "User's email address has suspicious parts: #{word}" if @user.email.include?(word)
    end
    
    add_score "20", "User has lots and lots of dots" if @user.email.split("@")[0].scan(/\./).size > 5
    
    add_score 5, "User is untrusted" if !@user.trusted?
  end
end