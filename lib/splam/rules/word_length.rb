class Splam::Rules::WordLength < Splam::Rule

  # Basic array functions
  def sum(arr)
    arr.inject  {|sum,x| sum + x }
  end

  def average(arr)
    sum(arr) / arr.size
  end
  
  def median(arr)
    a2 = arr.sort
    a2[arr.size / 2] unless arr.empty?
  end
  
  def run
    words = []
    words = @body.split("\s").map do |word|
      word.size
    end

    # Only count word lengths over 10
    if words.size > 10
      add_score 20, "Average word length over 5" if average(words) > 5
      add_score 50, "Average word length over 10" if average(words) > 10
      add_score 10, "Median word length over 5" if median(words) > 5
      add_score 50, "Median word length over 10" if median(words) > 10      
    end
  end
end