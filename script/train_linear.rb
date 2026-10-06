# Trains Splam::LinearScorer weights on a labelled JSONL set and evaluates
# them on its test rows.
#
#   ruby -Ilib script/train_linear.rb data.jsonl --out weights.json [options] > test_scores.jsonl
#
# Each line: {"id", "body", "title", "number", "label" (1/0), "slice", "split"
# ("train"/"test"), "features" (optional: the app's extra features, numbers)}.
# Features are computed as an app sees them: a body suite with the default
# rules and, on first comments with a title, a title suite (chinese,
# bad_words, href) named --title-field; the app's extra features; and
# text.log_odds from a Splam::TextModel trained on the train rows (out of fold
# for the train rows themselves, so no row is scored by a model that saw it).
#
# Options:
#   --out FILE           where the weights go (JSON)
#   --title-field NAME   the title suite's field (default title; Tender's is discussion_title)
#   --exclude a,b        rules left out (default keyhits,httpbl,geoip,user: request data/network)
#   --folds N            text model folds for the train rows (default 5)
#   --l2 X               ridge penalty on standardized weights (default 1.0)
#   --no-text            leave the text model out
require 'json'
require 'optparse'
require 'splam'

opts = { :out => nil, :title_field => 'title', :exclude => %w(keyhits httpbl geoip user), :folds => 5, :l2 => 1.0, :text => true }
OptionParser.new do |o|
  o.on('--out FILE') { |v| opts[:out] = v }
  o.on('--title-field NAME') { |v| opts[:title_field] = v }
  o.on('--exclude LIST') { |v| opts[:exclude] = v.split(',') }
  o.on('--folds N', Integer) { |v| opts[:folds] = v }
  o.on('--l2 X', Float) { |v| opts[:l2] = v }
  o.on('--no-text') { opts[:text] = false }
end.parse!

title_field = opts[:title_field].to_sym
Record = Struct.new(:body, title_field, :number) do
  include Splam
  def user; nil; end
end
excluded = opts[:exclude].map(&:to_sym)
body_rules = Splam::Rule.default_rules.reject { |r| excluded.include?(r.splam_key) }.select { |r| Splam.config.rule_enabled?(r) }
Record.splammable(:body, 250) { |s| s.rules = body_rules }
Record.splammable(title_field, 250, lambda { |r| r.number.to_i == 1 && !r.send(title_field).to_s.strip.empty? }) do |s|
  s.rules = [:chinese, :bad_words, :href].reject { |k| excluded.include?(k) }
end

$stderr.puts "reading and scoring rules..."
rows = []
ARGF.each_line do |line|
  d = JSON.parse(line)
  rec = Record.new(d['body'].to_s, d['title'].to_s, d['number'])
  result = rec.splam_result
  f = result ? result.features.dup : {}
  (d['features'] || {}).each { |k, v| f[k] = v.to_f }
  rows << { 'id' => d['id'], 'label' => d['label'].to_i, 'slice' => d['slice'], 'split' => d['split'],
            'text' => [d['title'], d['body']].compact.join("\n"), 'f' => f, 'classic' => result ? result.score : 0 }
end
train = rows.select { |r| r['split'] == 'train' }
test = rows.reject { |r| r['split'] == 'train' }

if opts[:text]
  $stderr.puts "text model: #{opts[:folds]} folds over #{train.size} train rows, then all of them for #{test.size} test rows..."
  new_model = lambda { Splam::TextModel.new(Splam::TextModel::MemoryStore.new) }
  label = lambda { |r| r['label'] == 1 ? :spam : :ham }
  opts[:folds].times do |k|
    model = new_model.call
    train.each_with_index { |r, i| model.train(r['id'], r['text'], label.call(r)) unless i % opts[:folds] == k }
    train.each_with_index { |r, i| r['f']['text.log_odds'] = model.score(r['text'])[:log_odds] if i % opts[:folds] == k }
  end
  model = new_model.call
  train.each { |r| model.train(r['id'], r['text'], label.call(r)) }
  test.each { |r| r['f']['text.log_odds'] = model.score(r['text'])[:log_odds] }
end

# the features: every one seen with some variation in the train rows
names = train.map { |r| r['f'].keys }.flatten.uniq.sort
transform_for = lambda do |name|
  if name =~ /\.rule\./ then { "transform" => "slog" }
  elsif name == "text.log_odds" then { "transform" => "clip", "min" => -50, "max" => 50 }
  else { "transform" => "raw" }
  end
end
specs = Hash[names.map { |n| [n, transform_for.call(n)] }]
x_of = lambda { |r| names.map { |n| Splam::LinearScorer.transform(specs[n], r['f'][n] || 0) } }
xs = train.map(&x_of)
means = names.each_index.map { |j| xs.inject(0.0) { |s, x| s + x[j] } / xs.size }
sds = names.each_index.map { |j| Math.sqrt(xs.inject(0.0) { |s, x| s + (x[j] - means[j])**2 } / xs.size) }
keep = names.each_index.select { |j| sds[j] > 1e-9 }
$stderr.puts "#{keep.size} features (#{names.size - keep.size} constant ones dropped)"
z = xs.map { |x| [1.0] + keep.map { |j| (x[j] - means[j]) / sds[j] } }
y = train.map { |r| r['label'].to_f }

# logistic regression, ridge on the standardized weights, by Newton's method
d = keep.size + 1
w = Array.new(d, 0.0)
solve = lambda do |a, b| # Gaussian elimination with partial pivoting
  n = b.size
  m = a.each_with_index.map { |row, i| row + [b[i]] }
  n.times do |c|
    p = (c...n).max_by { |i| m[i][c].abs }
    m[c], m[p] = m[p], m[c]
    (c + 1...n).each do |i|
      f = m[i][c] / m[c][c]
      (c..n).each { |k| m[i][k] -= f * m[c][k] }
    end
  end
  out = Array.new(n, 0.0)
  (n - 1).downto(0) { |i| out[i] = (m[i][n] - (i + 1...n).inject(0.0) { |s, k| s + m[i][k] * out[k] }) / m[i][i] }
  out
end
25.times do |iter|
  grad = Array.new(d, 0.0)
  hess = Array.new(d) { Array.new(d, 0.0) }
  z.each_with_index do |zi, i|
    p = Splam::TextModel.probability(zi.each_index.inject(0.0) { |s, k| s + w[k] * zi[k] })
    r = p * (1 - p)
    e = p - y[i]
    zi.each_index do |a|
      grad[a] += e * zi[a]
      ra = r * zi[a]
      (a...d).each { |b| hess[a][b] += ra * zi[b] }
    end
  end
  (1...d).each { |a| grad[a] += opts[:l2] * w[a]; hess[a][a] += opts[:l2] }
  (0...d).each { |a| (0...a).each { |b| hess[a][b] = hess[b][a] } }
  step = solve.call(hess, grad)
  w = w.each_index.map { |k| w[k] - step[k] }
  size = Math.sqrt(step.inject(0.0) { |s, v| s + v * v })
  $stderr.puts format("  newton %d: step %.2e", iter + 1, size)
  break if size < 1e-6
end

# back to the transformed (unstandardized) scale
features = {}
bias = w[0]
keep.each_with_index do |j, k|
  weight = w[k + 1] / sds[j]
  bias -= weight * means[j]
  features[names[j]] = specs[names[j]].merge("weight" => weight)
end
scorer = Splam::LinearScorer.new(bias, features)
File.write(opts[:out], JSON.pretty_generate(scorer.to_hash)) if opts[:out]
$stderr.puts "largest standardized weights: " +
  keep.each_with_index.map { |j, k| [names[j], w[k + 1]] }.sort_by { |_, v| -v.abs }.first(12).map { |n, v| format("%s %+.2f", n, v) }.join(", ")

# evaluate on the test rows
test.each do |r|
  r['p'] = scorer.probability(r['f'])
  r['logit'] = scorer.logit(r['f'])
  puts JSON.generate('id' => r['id'], 'label' => r['label'], 'slice' => r['slice'], 'logit' => r['logit'], 'classic' => r['classic'], 'text' => r['f']['text.log_odds'])
end
auc_ap = lambda do |key|
  pos = test.count { |r| r['label'] == 1 }
  neg = test.size - pos
  ranked = test.sort_by { |r| r[key] }
  rank_sum, i = 0.0, 0
  while i < ranked.size
    j = i
    j += 1 while j + 1 < ranked.size && ranked[j + 1][key] == ranked[i][key]
    (i..j).each { |k| rank_sum += (i + j) / 2.0 + 1 if ranked[k]['label'] == 1 }
    i = j + 1
  end
  ap, tp, seen = 0.0, 0, 0
  test.sort_by { |r| -r[key] }.chunk { |r| r[key] }.each do |_, g|
    seen += g.size
    hits = g.count { |r| r['label'] == 1 }
    tp += hits
    ap += hits * (tp.to_f / seen)
  end
  [(rank_sum - pos * (pos + 1) / 2.0) / (pos * neg), ap / pos]
end
$stderr.puts format("test: ROC AUC %.3f, average precision %.3f (%d rows)", *(auc_ap.call('logit') + [test.size]))
ordinary = test.select { |r| r['slice'].to_s.start_with?('random_ham') }.map { |r| r['logit'] }.sort.reverse
unless ordinary.empty?
  [0.002, 0.005, 0.01].each do |fpr|
    cut = ordinary[[(ordinary.size * fpr).to_i, ordinary.size - 1].min]
    by = test.group_by { |r| r['slice'] }.sort.map { |s, rs| format("%s %.1f%%", s, 100.0 * rs.count { |r| r['logit'] > cut } / rs.size) }
    $stderr.puts format("at %.1f%% of ordinary comments flagged (logit > %.2f): ", fpr * 100, cut) + by.join(" | ")
  end
end
