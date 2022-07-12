# encoding: UTF-8

class Splam::Rules::True < Splam::Rule

  # We get a number of spam comments that are just one word:
  # true, comment_body, "8趷", ...
  def run
    tokens = Splam::Ngram.tokenize @body.strip
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
      elsif @body =~ /([a-z])\1{5,}/
        add_score 50, "Repeated letter (6+)"
      elsif @body =~ /([a-z])\1{2,}/
        add_score 50, "Repeated letter (3-6)"
      end

      mashing = /asd[das]|asad|csfd|fdsd|sdf[gd]|zx[cv][zc]|cvb|dsfs|asdf|sadf|dfgd|bvbn/
      if res = @body.scan(mashing)
        add_score res.size * 20, "Mashing keyboard"
      end
    end
  end
  
end
