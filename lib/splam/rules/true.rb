# encoding: UTF-8

class Splam::Rules::True < Splam::Rule

  # We get a number of spam comments that are just one word:
  # true, comment_body, "8趷", ...
  def run
    tokens = @document.tokens
    if tokens.size == 1
      add_score 100, "Body is just one word" 
      if @body =~ /[bvcgf]{20,}/
        add_score 100, "Repeated bvcgf (20+)"
      elsif @body =~ /[hjgbn]{20,}/
        add_score 100, "Repeated hjgbn (20+)"
      elsif @body =~ /[nvgh]{20,}/
        add_score 100, "Repeated nvgh (20+)"
      elsif @body =~ /[esdszfxca]{20,}/
        add_score 100, "Repeated esdzf (20+)"
      elsif @body =~ /[asdfghjkl]{20,}/
        add_score 100, "Repeated letter (20+)"
      elsif @body =~ /[hjgkl]{20,}/
        add_score 100, "Repeated hjgkl (20+)"
      elsif repeated_letters?(5)
        add_score 50, "Repeated letter (6+)"
      elsif repeated_letters?(2)
        add_score 50, "Repeated letter (3-6)"
      end

      mashing = /asd[das]|asad|csfd|fdsd|sdf[gd]|zx[cv][zc]|cvb|dsfs|asdf|sadf|dfgd|bvbn/
      if res = @body.scan(mashing)
        add_score res.size * 20, "Mashing keyboard"
      end
    end
  end
  

  private

  # A letter repeated more than `times` times ("aaa"). Before 0.5 the default
  # profile checked any run of times + 1 letters, which every ordinary word matches.
  def repeated_letters?(times)
    @body =~ /([a-z])\1{#{times},}/
  end
end
