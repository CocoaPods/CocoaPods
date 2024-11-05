Pod::Spec.new do |s|
  s.name         = "sharedlib"
  s.version      = "0.0.1"
  s.summary      = "summary: The summary is not meaningful.summary: The summary is not meaningful.summary: The summary is not meaningful.summary: The summary is not meaningful.summary: The summary is not meaningful.summary: The summary is not meaningful.summary: The summary is not meaningful."
  s.description  = <<-DESC 
  not emptynot emptynot emptynot emptynot emptynot empty
                   DESC
  s.homepage     = "http://blalblalba/testutils"
  s.license      = "MIT"
  s.author             = { "Felipe Cypriano" => "felipe@thumbtack.com" }
  s.source       = { path: '.' }

  s.subspec 'Core' do |core|
    core.source_files  = "Classes/Core/*.{h,m}"
    core.dependency "asserts"
    core.dependency "logger"
  end

  s.subspec 'Testing' do |t|
    t.source_files  = "Classes/Testing/*.{h,m}"
    t.dependency 'testkit'
  end
end
