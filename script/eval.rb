# Scores a labelled JSONL set with whichever splam is first on the load path, and
# prints flag rates per slice and ranking quality, so two versions can be compared
# on the same data.
#
#   ruby -Ilib -rlogger -raddressable/uri script/eval.rb data.jsonl [options] > scores.jsonl
#
# Each input line: {"id", "body", "title", "label" (1 spam / 0 ham), "slice", "number",
# "split" (optional, e.g. train/test)}. Lines are scored the way Tender scores a
# comment: a body suite with the default rules, plus a title suite
# (chinese, bad_words, href) on the first comment, summed.
#
# Options:
#   --threshold N     flag when score > N (default 250, Tender's Job::CheckSpam)
#   --exclude a,b     rules left out (default: keyhits,httpbl,geoip,user; they need
#                     request data or network)
#   --split NAME      only summarise rows with this split (all rows are still scored)
#   --profile NAME    Splam.config.profile (splam >= 0.3.1)
require 'json'
require 'optparse'
require 'splam'

opts = { :threshold => 250.0, :exclude => %w(keyhits httpbl geoip user), :split => nil, :profile => nil }
OptionParser.new do |o|
  o.on('--threshold N', Float) { |v| opts[:threshold] = v }
  o.on('--exclude LIST') { |v| opts[:exclude] = v.split(',') }
  o.on('--split NAME') { |v| opts[:split] = v }
  o.on('--profile NAME') { |v| opts[:profile] = v }
end.parse!
Splam.configure { |c| c.profile = opts[:profile].to_sym } if opts[:profile]

class EvalRecord
  include Splam
  attr_accessor :body, :title, :number
  def user; nil; end
  def first?; number.to_i == 1; end
end
excluded = opts[:exclude].map(&:to_sym)
body_rules = Splam::Rule.default_rules.reject { |r| excluded.include?(r.splam_key) }
body_rules = body_rules.select { |r| Splam.config.rule_enabled?(r) } if Splam.respond_to?(:config)
title_rules = [:chinese, :bad_words, :href].reject { |k| excluded.include?(k) }
EvalRecord.splammable(:body, opts[:threshold]) { |s| s.rules = body_rules }
# no title suite without a title: in labelled sets built after spam was purged
# the title is often missing, which isn't what the app sees
EvalRecord.splammable(:title, opts[:threshold], lambda { |r| r.first? && !r.title.to_s.strip.empty? }) { |s| s.rules = title_rules }

rows = []
t0 = Time.now
ARGF.each_line do |line|
  d = JSON.parse(line)
  rec = EvalRecord.new
  rec.body, rec.title, rec.number = d['body'].to_s, d['title'].to_s, d['number']
  score = begin
    rec.splam_score
  rescue StandardError => e
    $stderr.puts "#{d['id']}: #{e.class}: #{e.message[0, 120]}"
    nil
  end
  row = { 'id' => d['id'], 'score' => score, 'label' => d['label'].to_i, 'slice' => d['slice'], 'split' => d['split'] }
  rows << row
  puts JSON.generate(row)
end
secs = Time.now - t0

sel = rows.select { |r| r['score'] && (opts[:split].nil? || r['split'] == opts[:split]) }
$stderr.puts format('%d rows scored in %.1fs (%.2f ms each), %d errors; summarising %d%s; threshold > %g; rules left out: %s',
                    rows.size, secs, secs * 1000 / [rows.size, 1].max, rows.count { |r| r['score'].nil? }, sel.size,
                    opts[:split] ? " (split #{opts[:split]})" : '', opts[:threshold], excluded.join(','))
sel.group_by { |r| r['slice'] }.sort.each do |slice, rs|
  flagged = rs.count { |r| r['score'] > opts[:threshold] }
  $stderr.puts format('  %-28s n=%6d  flagged %6.1f%%  (label %s)', slice, rs.size, 100.0 * flagged / rs.size, rs.map { |r| r['label'] }.uniq.sort.join('/'))
end

# ROC AUC by ranks (ties averaged) and average precision, over the selected rows
pos = sel.count { |r| r['label'] == 1 }
neg = sel.size - pos
if pos > 0 && neg > 0
  ranked = sel.sort_by { |r| r['score'] }
  rank_sum, i = 0.0, 0
  while i < ranked.size
    j = i
    j += 1 while j + 1 < ranked.size && ranked[j + 1]['score'] == ranked[i]['score']
    avg = (i + j) / 2.0 + 1
    (i..j).each { |k| rank_sum += avg if ranked[k]['label'] == 1 }
    i = j + 1
  end
  auc = (rank_sum - pos * (pos + 1) / 2.0) / (pos * neg)
  ap, tp, seen = 0.0, 0, 0
  sel.sort_by { |r| -r['score'] }.chunk { |r| r['score'] }.each do |_, group|
    seen += group.size
    hits = group.count { |r| r['label'] == 1 }
    tp += hits
    ap += hits * (tp.to_f / seen)
  end
  $stderr.puts format('  ROC AUC %.3f  average precision %.3f  (spam %d, ham %d)', auc, ap / pos, pos, neg)
end
