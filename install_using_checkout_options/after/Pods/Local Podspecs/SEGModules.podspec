Pod::Spec.new do |s|
  s.name         = "SEGModules"
  s.version      = "0.1.0"
  s.summary      = "A library to bring modules/mixins/concrete protocols to Objective-C."
  s.homepage     = "https://github.com/segiddins/SEGModules"
  s.license      = 'MIT'
  s.author       = { "Samuel E. Giddins" => "segiddins@segiddins.me" }
  s.source       = { :git => "#{s.homepage}.git", :tag => "v#{s.version}" }

  s.requires_arc = false

  s.source_files = 'Classes'

  s.ios.exclude_files = 'Classes/osx'
  s.osx.exclude_files = 'Classes/ios'
end

