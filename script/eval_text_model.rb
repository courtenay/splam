# Trains Splam::TextModel (in memory) on a labelled JSONL set's "train" rows
# and scores its "test" rows: ROC AUC, average precision and flag rates per
# slice at a few probability cut-offs.
#
#   ruby -Ilib script/eval_text_model.rb data.jsonl [--max-chars N] [--alpha A] > scores.jsonl
#
# Each line: {"id", "body", "title", "label" (1 spam / 0 ham), "slice", "split"}.
# The text is the title and body, as an app would train on them.
require 'json'
require 'optparse'
require 'splam'

opts = { :max_chars => 1000, :alpha => 1.0 }
OptionParser.new do |o|
  o.on('--max-chars N', Integer) { |v| opts[:max_chars] = v }
  o.on('--alpha A', Float) { |v| opts[:alpha] = v }
end.parse!

model = Splam::TextModel.new(Splam::TextModel::MemoryStore.new, :max_chars => opts[:max_chars], :alpha => opts[:alpha])
text = lambda { |d| [d['title'], d['body']].compact.join("\n") }
test = []
t0 = Time.now
ARGF.each_line do |line|
  d = JSON.parse(line)
  if d['split'] == 'train'
    model.train(d['id'], text.call(d), d['label'].to_i == 1 ? :spam : :ham)
  else
    test << d
  end
end
trained = Time.now - t0
rows = test.map do |d|
  r = model.score(text.call(d))
  row = { 'id' => d['id'], 'label' => d['label'].to_i, 'slice' => d['slice'], 'p' => r[:probability], 'log_odds' => r[:log_odds] }
  puts JSON.generate(row)
  row
end
$stderr.puts format('trained in %.1fs (%s); scored %d test rows in %.1fs', trained, model.stats.inspect, rows.size, Time.now - t0 - trained)

pos = rows.count { |r| r['label'] == 1 }
neg = rows.size - pos
ranked = rows.sort_by { |r| r['log_odds'] }
rank_sum, i = 0.0, 0
while i < ranked.size
  j = i
  j += 1 while j + 1 < ranked.size && ranked[j + 1]['log_odds'] == ranked[i]['log_odds']
  avg = (i + j) / 2.0 + 1
  (i..j).each { |k| rank_sum += avg if ranked[k]['label'] == 1 }
  i = j + 1
end
ap, tp, seen = 0.0, 0, 0
rows.sort_by { |r| -r['log_odds'] }.chunk { |r| r['log_odds'] }.each do |_, group|
  seen += group.size
  hits = group.count { |r| r['label'] == 1 }
  tp += hits
  ap += hits * (tp.to_f / seen)
end
$stderr.puts format('ROC AUC %.3f  average precision %.3f  (spam %d, ham %d)', (rank_sum - pos * (pos + 1) / 2.0) / (pos * neg), ap / pos, pos, neg)
[0.5, 0.9, 0.99].each do |cut|
  $stderr.puts "  flagged at p > #{cut}:"
  rows.group_by { |r| r['slice'] }.sort.each do |slice, rs|
    $stderr.puts format('    %-28s %6.1f%%', slice, 100.0 * rs.count { |r| r['p'] > cut } / rs.size)
  end
end
