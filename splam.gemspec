name = "splam"

Gem::Specification.new name, "0.4.0" do |s|
  s.summary = "Test comments and users for spam signifiers and score"
  s.description = "Splam is a modular spam detection library with rule-based heuristics and Bayesian classification"
  s.authors = ["ENTP"]
  s.email = "courtenay@entp.com"
  s.homepage = "http://github.com/courtenay/splam"
  s.files = `git ls-files`.split("\n")
  s.license = "MIT"

  s.required_ruby_version = ">= 2.2.3"

  s.add_runtime_dependency "activesupport", ">= 4.0"

  s.metadata = {
    "source_code_uri" => "https://github.com/courtenay/splam",
    "changelog_uri" => "https://github.com/courtenay/splam/blob/master/CHANGELOG.md",
    "bug_tracker_uri" => "https://github.com/courtenay/splam/issues"
  }
end