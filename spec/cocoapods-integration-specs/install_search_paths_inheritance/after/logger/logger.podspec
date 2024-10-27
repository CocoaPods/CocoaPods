Pod::Spec.new do |s|
  s.name         = "logger"
  s.version      = "0.0.1"
  s.summary      = "summary: The summary is not meaningful.summary: The summary is not meaningful.summary: The summary is not meaningful.summary: The summary is not meaningful.summary: The summary is not meaningful.summary: The summary is not meaningful.summary: The summary is not meaningful."
  s.description  = <<-DESC 
  not emptynot emptynot emptynot emptynot emptynot empty
                   DESC
  s.homepage     = "http://blalblalba/testutils"
  s.license      = "MIT"
  s.author             = { "Felipe Cypriano" => "felipe@thumbtack.com" }
  s.source       = { path: '.' }
  s.default_subspecs = 'Core'

  s.subspec 'Core' do |c|
    c.source_files  = "Classes/**/*.{h,m}"

    c.dependency "CocoaLumberjack", '3.0.0'
  end

  s.subspec 'Crashlytics' do |cr|
    cr.dependency 'CrashlyticsRecorder'
  end
end
