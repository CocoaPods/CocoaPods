Pod::Spec.new do |s|
  s.name         = "MercurialSource"
  s.version      = "0.0.1"
  s.summary      = "A short description of MercurialSource."
  s.homepage     = "http://EXAMPLE/MercurialSource"
  s.license      = 'MIT (example)'
  s.author       = { "Dan Cutting" => "dcutting@gmail.com" }
  s.source       = { :git => "http://EXAMPLE/MercurialSource.git", :tag => "0.0.1" }
  s.source_files = 'Classes', 'Classes/**/*.{h,m}'
end
