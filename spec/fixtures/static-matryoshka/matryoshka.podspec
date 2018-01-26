Pod::Spec.new do |s|
  s.name             = "matryoshka"
  s.version          = "1.0.0"
  s.author           = { "Matryona Malyutin" => "matryona@malyutin.local" }
  s.summary          = "👩‍👩‍👧"
  s.description      = "Four levels: outmost (root), outer, inner"
  s.homepage         = "http://httpbin.org/html"
  s.source           = { :git => "http://malyutin.local/matryoshka.git", :tag => s.version.to_s }
  s.license          = 'MIT'
  s.static_framework = true

  s.source_files = 'Outmost.{h,m}'
  s.dependency 'monkey'
end
