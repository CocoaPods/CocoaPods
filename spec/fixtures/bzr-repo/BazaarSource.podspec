Pod::Spec.new do |s|
  s.name         = "BazaarSource"
  s.version      = "0.0.1"
  s.summary      = "A short description of BazaarSource."
  s.homepage     = "http://EXAMPLE/BazaarSource"
  s.license      = 'MIT (example)'
  s.author       = { "Fred McCann" => "fred@sharpnoodles.com" }
  s.source       = { :git => "http://EXAMPLE/BazaarSource.git", :tag => "0.0.1" }
  s.source_files = 'Classes', 'Classes/**/*.{h,m}'
end
