name = "splam"

Gem::Specification.new name, "0.3.1" do |s|
  s.summary = "Test comments and users for spam signifiers and score"
  s.authors = ["ENTP"]
  s.email = "courtenay@entp.com"
  s.homepage = "http://github.com/courtenay/splam"
  s.files = Dir["lib/**/*.rb", "README", "MIT-LICENSE", "CHANGELOG.md"]
  s.license = "MIT"
  s.required_ruby_version = ">= 2.2"
  s.add_runtime_dependency "addressable"
end