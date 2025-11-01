name = "splam"

Gem::Specification.new name, "1.0.0" do |s|
  s.summary = "Test comments and users for spam signifiers and score"
  s.description = "Splam is a modular spam detection library with rule-based heuristics and Bayesian classification. " \
                  "v1.0 modernized for Ruby 3.1+ with improved performance and modern syntax."
  s.authors = ["ENTP"]
  s.email = "courtenay@entp.com"
  s.homepage = "http://github.com/courtenay/splam"
  s.files = `git ls-files`.split("\n")
  s.license = "MIT"

  s.required_ruby_version = ">= 3.1.0"

  s.add_runtime_dependency "activesupport", ">= 7.0"

  s.metadata = {
    "source_code_uri" => "https://github.com/courtenay/splam",
    "changelog_uri" => "https://github.com/courtenay/splam/blob/master/CHANGELOG.md",
    "bug_tracker_uri" => "https://github.com/courtenay/splam/issues",
    "rubygems_mfa_required" => "true"
  }
end