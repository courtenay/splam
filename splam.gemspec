name = "splam"

Gem::Specification.new name, "0.3.0" do |s|
  s.summary = "Test comments and users for spam signifiers and score"
  s.authors = ["ENTP"]
  s.email = "courtenay@entp.com"
  s.homepage = "http://github.com/courtenay/splam"
  s.files = `git ls-files`.split("\n")
  s.license = "MIT"
  s.add_runtime_dependency "activesupport"
end