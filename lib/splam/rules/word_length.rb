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
    # links don't count (before 0.5 this filtered the lengths, not the words, so it never did)
    words = @body.split(/\s/).reject { |word| word =~ /^https?:\/\// }.map(&:size)

    # Only count word lengths over 10
    if words.size > 5
      add_score 20, "Average word length over 5"  if average(words) > 5
      add_score 50, "Average word length over 10" if average(words) > 10
      add_score 10, "Median word length over 5"   if median(words) > 5
      add_score 50, "Median word length over 10"  if median(words) > 10
    end
  end
end