# A near-copy of an earlier text by someone else, with a link the earlier
# text didn't have: spam that re-posts a real comment (sometimes reworded)
# and adds a link. The app finds the candidates (Splam.config.similar_texts);
# this rule compares them. It adds features for a trained scorer, no points.
class Splam::Rules::Copycat < Splam::Rule
  URL = %r{https?://[^\s<>"'\])]+}
  WORD = /[[:alpha:]]{3,}/

  # share of distinct words (3+ letters, links left out) the two texts have in common
  def self.overlap(a, b)
    wa, wb = words(a), words(b)
    return 0.0 if wa.empty? || wb.empty?
    (wa & wb).size.to_f / (wa | wb).size
  end

  def self.words(text)
    text.to_s.downcase.gsub(URL, " ").scan(WORD).uniq
  end

  def run
    lookup = Splam.config.similar_texts
    return unless lookup
    matches = begin
      Array(lookup.call(@record, @body))
    rescue StandardError
      [] # a failing lookup mustn't stop a comment being checked
    end
    candidates = matches.reject { |m| m[:same_author] }.map do |m|
      [m[:similarity] || self.class.overlap(@body, m[:text]), m[:text].to_s]
    end
    return if candidates.empty?
    similarity, source = candidates.max_by(&:first)
    added = @body.scan(URL).uniq - source.scan(URL)
    last = @body.strip[/#{URL}\z/o]
    add_feature "copy.similarity", similarity.to_f
    add_feature "copy.added_links", added.size
    add_feature "copy.trailing_link", (last && added.include?(last)) ? 1 : 0
  end
end
