Pod::Spec.new do |s|
  s.name         = "Moment"
  s.version      = "0.0.1"
  s.summary      = "Natural language date parser using Lex/Yacc/C."
  s.homepage     = "https://github.com/kmussel/Moment"
  s.license      = 'MIT'
  s.author       = 'kmussel'
  s.source       = { :git => "https://github.com/kmussel/Moment.git", :commit => "39f21fee0cef410c6d89c9fa94ff5638527ef7bc" }
  s.source_files = 'TimeParser.{c,h}', 'parseIt.ym', 'tokeIt.l'
  s.requires_arc = false
end
