name = "splam"

Gem::Specification.new name, "0.1.0" do |s|
  s.summary = "Run any kind of code in parallel processes"
  s.authors = ["ENTP"]
  s.email = "ENTP@example.com"
  s.homepage = "http://github.com/grosser/#{name}"
  s.files = `git ls-files`.split("\n")
  s.license = "MIT"
  s.signing_key = File.expand_path("~/.ssh/gem-private_key.pem")
  s.cert_chain = ["gem-public_cert.pem"]
end
