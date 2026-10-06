# Changelog

## 0.6.0 (2026-10-07)

The architecture for a trained scorer. So far scores don't change: every step
was compared row by row with 0.5.0 on 10,810 labelled Tender comments, with
both profiles (0 rows differ).

- Needs Ruby 2.6 or newer (Tender and Lighthouse both run 2.6); CI tests 2.6 and 3.3.
- `Splam::Document`: a suite prepares the text once (valid UTF-8, downcased
  copy, link scans, tokens) and shares it with every rule. `Rule#initialize`
  takes it as an optional fifth argument.
- `splam_rule_scores`: field => { rule => score }, for scorers that weigh rules.
- Word lists are data files: `data/bad_words/*.txt` (the :lighthouse profile
  adds `data/bad_words/lighthouse/*.txt`), `data/suspicious_words.txt` and
  `data/good_words.txt`, one entry per line (a string, or `re:/regex/flags`).
  They are read once per process, and each entry's Regexp is compiled once;
  checks are 2-3x faster (7 ms per comment on the labelled set, from 17-24).
- `Splam::TextModel`: Naive Bayes for any language (word unigrams and trigrams,
  character pairs for Chinese and Japanese), from the 2025 Bayesian branch's
  maths. Training is keyed by document id: the same label again does nothing,
  a new one moves the counts once, and counts never go below zero. Stores:
  `MemoryStore`, and `RedisStore` (one HMGET per label per score; vocabulary and
  totals are counters, never read by scanning a hash). Not used by the rules or
  the score yet. `script/eval_text_model.rb` trains and scores it offline: on
  Tender's labelled comments (train before 2023, test after) ROC AUC .944,
  average precision .897, against .641 / .462 for the rules.
- Features, scores and the Linear scorer. Rules add named features next to
  their points (`add_feature`); a model's `splam_result` (a `Splam::Result`) has
  the score, reasons, features (`<field>.rule.<key>`, rule features, an app's
  extra features, `text.log_odds`) and, with `Splam.config.scorer`, a
  probability. `Splam::LinearScorer` is logistic regression over the features
  from a JSON weights file. `Splam.check(text, ...)` does the same without a
  model class. Hooks: `text_model`, `text_for`, `extra_features`,
  `similar_texts`, `scorer`.
- Copycat: with an app's `similar_texts` lookup, a near-copy of an earlier
  text by someone else adds `copy.similarity`, `copy.added_links` and
  `copy.trailing_link` (features only, no points).
- `script/train_linear.rb` trains weights offline. On Tender's labelled
  comments (rules, Tender's request signals and the text model; test after
  2023) ROC AUC .946, average precision .908. At 0.5% of ordinary comments
  flagged it flags 0.4% of the comments staff restored (the rules: 41.8%) and
  catches 30.7% of a sample of auto-hidden spam (24.0%) and 10.0% of spam
  people reported (2.1%). Weights trained on an app's data stay with the app.

## 0.5.0 (2026-10-06)

(Released as 0.5.0: the v0.4.0 tag belongs to the unmerged 2025 Bayesian
filter branch.)

Rule fixes. Scores change; each change was measured on 10,810 labelled Tender
comments (2023 onward) with `script/eval.rb`. Flag rates at Tender's `> 250`,
default profile, text rules only:

| | ordinary comments | restored customer comments | hand-reported spam | sample of auto-hidden spam |
|---|---|---|---|---|
| 0.3.1 | 0.5% | 51.1% | 2.4% | 25.3% |
| 0.5.0 | 0.3% | 41.8% | 2.1% | 24.0% |

- GoodWords matches. It scanned the string `"\b#{word}\b"`, whose `\b` are
  backspaces, so it never did. Each word or phrase now matches whole, at -5 per
  occurrence.
- BadWords: the link-text bonus counts the word inside each link. It added
  `bad_word_score**4` for every link on the page once any bad word appeared.
  (The largest change: restored customer comments flagged went from 50.7% to 45.4%.)
- BadWords: the one-genre bonus (+50) is added once per genre, not once per word
  after the genre passed half its list.
- BadWords: `\b` goes only on a side of an entry that is a word character, so
  entries that start or end in punctuation ("dear,", "<<<91", the "[(][+]1[)]"
  phone patterns) can match; everything that matched before still does. The two
  capitalised support-scam regexes get `/i` (they run on a downcased body).
- Russian: each listed letter scores once (о, р and т were listed 3, 3 and 2 times).
- True: "repeated letter" means a letter repeated (`aaa`) with every profile; the
  default profile matched any run of 3 or 6 letters, i.e. nearly every word.
- Href: a blank body no longer counts as "just http tokens" (+50).
- Bbcode: `[img` is counted; `[IMG` was counted twice.
- WordLength: links (http and https) are left out of the word lengths, as
  intended; the filter ran on the lengths, so it never matched.
- :lighthouse profile: User's `check_badlist` no longer flags every user (+50);
  Html's "Don't get too excited" (+20) needs a `!`; Fuzz runs (it returned early
  on every body) and its aggregate score uses the count, not `Integer#size`.
- Korean text no longer scores for its script: the Chinese rule drops the
  Hangul blocks and the Korean rule is opt-in. In Tender's labelled comments
  Korean was nearly all ham (restored customer comments flagged: 45.1% to 41.8%,
  no spam lost). Chinese and Japanese ideographs still score; the word rules
  can't read them, and dropping them also loses spam, so they wait for a text
  model that learns from any language.
- script/eval.rb skips the title suite when a row has no title (labelled sets
  built after spam was purged often lack it).
- Fixture tests: the default profile flags no ham fixture (was 1) and misses 7
  spam fixtures (was 4); the :lighthouse profile flags 4 ham fixtures (was 12)
  and misses 2 spam ones (was 0).

## 0.3.1 (2026-10-06)

One gem again: Tender's copy and 0.3.0 merged. Scores are unchanged for both:
the default profile scores exactly as Tender's copy did, and the :lighthouse
profile exactly as 0.3.0 did, checked on 38,375 labelled comments.

- `Splam.configure`: a profile (`:default`, Tender's tuning; `:lighthouse`, 0.3.0's),
  rule weight overrides, and `bad_word_score`.
- Opt-in rules (`Rule.opt_in?`): Fuzz and LineLength run only with the
  :lighthouse profile, or when a suite names them.
- Linear-time scans for every link regex that could take quadratic time on a
  hostile body (`<a<a<a…`, `http://http://…`, `love love …`, a trailing tag
  after many `<`), with tests that they find what the regexes found.
- Invalid UTF-8 in a body is scrubbed instead of raising.
- Per-field results from 0.3.0 (`splam_scores`, `splam?(field)`), plus
  `splam_reasons_by_field`. `splam_reasons` is a flat array again (one array per
  rule), as both apps' views expect.
- `splam?` with no field is false for a suite that didn't run (it raised).
- Fractional rule weights count (`weight.to_i` made 0.5 into 0). Neither app
  used one, so no score changes.
- `record.user` is optional; the user-record checks run with the :lighthouse
  profile. "User has lots of dots" no longer raises (it passed a String score).
- Httpbl checks the app's `ip.<ip>` cache first, queries DNS only with an
  `api_key`, and treats a DNS timeout or refusal as "not listed" (they raised).
- ArmsRace no longer scores a "bflood" ending (+200 in Tender's copy, for one
  long-gone spammer; no comment in the labelled set ended that way).
- Keyhits is no longer referenced: it's Tender's own rule. The tests use an
  example app rule instead.
- Runs on Ruby 3.2+: WordLength called `=~` on Integers (it never matched, so
  removing it changes no score).
- No ActiveSupport dependency (rule keys are derived locally, same keys).
- Tests run on Ruby 2.2, 2.6 and 3.3; the fixture tests list, per profile, the
  fixtures each tuning gets wrong today. `script/eval.rb` compares versions on
  labelled data.
