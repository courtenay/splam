# Changelog

## 0.3.1 (unreleased)

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
