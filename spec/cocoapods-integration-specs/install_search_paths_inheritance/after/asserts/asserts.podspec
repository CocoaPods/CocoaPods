Pod::Spec.new do |s|
  s.name         = "asserts"
  s.version      = "0.0.1"
  s.summary      = "summary: The summary is not meaningful.summary: The summary is not meaningful.summary: The summary is not meaningful.summary: The summary is not meaningful.summary: The summary is not meaningful.summary: The summary is not meaningful.summary: The summary is not meaningful."
  s.description  = <<-DESC 
  not emptynot emptynot emptynot emptynot emptynot empty
                   DESC
  s.homepage     = "http://blalblalba/testutils"
  s.license      = "MIT"
  s.author       = { "Felipe Cypriano" => "felipe@thumbtack.com" }
  s.source       = { path: '.' }

  s.source_files  = "Classes", "Classes/**/*.{h,m}"
  s.exclude_files = "Classes/Exclude"

  s.dependency "logger"
end
